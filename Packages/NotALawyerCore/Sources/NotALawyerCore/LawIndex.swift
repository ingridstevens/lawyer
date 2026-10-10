import CSQLite
import Foundation

/// The law collection plus a SQLite FTS5 keyword index over its paragraphs (spec §9).
///
/// The index is built in memory when loaded. The five v1 laws are ~1.4 MB of XML,
/// which parses and indexes in well under a second, so there is no cache to go stale.
public final class LawIndex: @unchecked Sendable {
    public let sections: [LawSection]
    /// Oldest "as of" date across the laws. A law that hasn't changed keeps an old date, so this
    /// says nothing about staleness; use `checkedAt` for that.
    public let asOf: Date
    /// When this collection was last downloaded from, and so checked against, the official site.
    public private(set) var checkedAt: Date?
    /// Each law's own version date.
    public var lawDates: [(law: String, asOf: Date)] {
        laws.compactMap { law in sections.first { $0.law == law }.map { (law, $0.asOf) } }
    }
    private let passages: [LawPassage]
    private let sectionsByKey: [String: LawSection]
    private let lock = NSLock()
    private var db: OpaquePointer?

    public init(sections: [LawSection]) throws {
        self.sections = sections
        self.asOf = sections.map(\.asOf).min() ?? Date(timeIntervalSince1970: 0)
        self.passages = sections.flatMap { s in s.paragraphs.map { LawPassage(section: s, paragraph: $0) } }
        self.sectionsByKey = Dictionary(sections.map { (Self.key($0.law, $0.number), $0) }, uniquingKeysWith: { a, _ in a })
        try openAndFill()
    }

    /// Loads every v1 law found in `directory` as `<slug>.xml`.
    public convenience init(directory: URL, sources: [LawSource] = LawSource.v1) throws {
        var all: [LawSection] = []
        for source in sources {
            let url = directory.appendingPathComponent("\(source.slug).xml")
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            all += try LawXMLParser.parse(fileAt: url, source: source)
        }
        guard !all.isEmpty else { throw LawIndexError.noLawsFound(directory) }
        try self.init(sections: all)
        checkedAt = Self.readCheckedDate(in: directory)
    }

    /// `checked.txt` holds the day the laws were downloaded, as yyyy-MM-dd.
    public static let checkedFile = "checked.txt"

    static func readCheckedDate(in directory: URL) -> Date? {
        guard let text = try? String(contentsOf: directory.appendingPathComponent(checkedFile), encoding: .utf8) else { return nil }
        return try? Date(text.trimmingCharacters(in: .whitespacesAndNewlines), strategy: .iso8601.year().month().day())
    }

    deinit { sqlite3_close(db) }

    public func section(law: String, number: String) -> LawSection? {
        sectionsByKey[Self.key(law, number)]
    }

    /// Laws present in the collection, e.g. ["AufenthG", "StAG"].
    public var laws: [String] { Array(Set(sections.map(\.law))).sorted() }

    // MARK: Search

    /// Keyword search. `terms` are ORed; each matches as a word prefix so that
    /// "Niederlassung" also finds "Niederlassungserlaubnis". `lawBoost` multiplies
    /// the score of passages from the given laws (profile filter, spec §9).
    public func search(terms: [String], lawBoost: [String: Double] = [:], limit: Int = 12) -> [LawPassage] {
        let query = Self.ftsQuery(terms)
        guard !query.isEmpty else { return [] }
        lock.lock(); defer { lock.unlock() }

        // bm25 is lower-is-better; heading matches weigh 4x.
        let sql = "SELECT rowid, bm25(fts, 4.0, 1.0) FROM fts WHERE fts MATCH ? ORDER BY bm25(fts, 4.0, 1.0) LIMIT 200"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, query, -1, Self.transient)

        var scored: [(LawPassage, Double)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = Int(sqlite3_column_int64(stmt, 0)) - 1
            let passage = passages[row]
            let boost = (lawBoost[passage.section.law] ?? 1) * Self.weight(of: passage.section)
            scored.append((passage, -sqlite3_column_double(stmt, 1) * boost))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    /// Section references written in the question, e.g. "§ 18a" or "§ 10 StAG".
    /// Without a law name, every law that has that section number is returned.
    public func referencedSections(in text: String, requireLaw: Bool = false) -> [LawSection] {
        var found: [LawSection] = []
        for match in text.matches(of: /§\s*(\d+[a-z]?)(?:\s+(?:Abs\.\s*\d+[a-z]?\s+)?([A-Za-zÄÖÜäöüß\/]+))?/) {
            let number = String(match.1)
            if let law = match.2.map(String.init), let s = section(law: law, number: number) {
                found.append(s)
            } else if !requireLaw {
                found += sections.filter { $0.number == number }
            }
        }
        var seen = Set<String>()
        return found.filter { seen.insert($0.label).inserted }
    }

    /// Administrative sections (statistics, registers, data transfer) mention the topic words
    /// often but rarely answer a user's question; § 36 StAG kept outranking § 10 StAG.
    static func weight(of section: LawSection) -> Double {
        let n = Int(section.number.prefix { $0.isNumber }) ?? 0
        switch section.law {
        case "StAG" where [31, 32, 33, 36].contains(n): return 0.25
        case "AufenthG" where (86...91).contains(n): return 0.25
        default: return 1
        }
    }

    // MARK: SQLite

    private func openAndFill() throws {
        guard sqlite3_open(":memory:", &db) == SQLITE_OK else { throw LawIndexError.sqlite("open") }
        try exec("CREATE VIRTUAL TABLE fts USING fts5(heading, text, tokenize = 'unicode61 remove_diacritics 2')")
        try exec("BEGIN")
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO fts(rowid, heading, text) VALUES (?, ?, ?)", -1, &stmt, nil) == SQLITE_OK else {
            throw LawIndexError.sqlite("prepare insert")
        }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in passages.enumerated() {
            sqlite3_reset(stmt)
            sqlite3_bind_int64(stmt, 1, Int64(i + 1))
            sqlite3_bind_text(stmt, 2, p.section.heading, -1, Self.transient)
            sqlite3_bind_text(stmt, 3, p.paragraph.text, -1, Self.transient)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw LawIndexError.sqlite("insert") }
        }
        try exec("COMMIT")
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw LawIndexError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static func key(_ law: String, _ number: String) -> String { "\(law.lowercased())|\(number.lowercased())" }

    /// Builds an FTS5 query from free terms: `"term"* OR "two words"`.
    static func ftsQuery(_ terms: [String]) -> String {
        var seen = Set<String>()
        return terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
            .filter { $0.count >= 3 && seen.insert($0.lowercased()).inserted }
            .map { $0.contains(" ") ? "\"\($0)\"" : "\"\($0)\"*" }
            .joined(separator: " OR ")
    }
}

public enum LawIndexError: Error, LocalizedError {
    case noLawsFound(URL)
    case sqlite(String)

    public var errorDescription: String? {
        switch self {
        case .noLawsFound(let url): "No law files found in \(url.path)."
        case .sqlite(let message): "Search index error: \(message)"
        }
    }
}
