import Foundation
import NotALawyerCore
import Observation

/// What a document is. German first, because that's what's printed on it.
enum DocumentKind: String, Codable, CaseIterable, Identifiable {
    case languageCertificate, citizenshipTest, integrationCourse, pensionRecord, employmentContract, payslip
    case taxAssessment, rentalContract, residenceCard, passport, degree, registration, application, decision, other

    var id: Self { self }

    var german: String {
        switch self {
        case .languageCertificate: "Sprachzertifikat"
        case .citizenshipTest: "Einbürgerungstest / Leben in Deutschland"
        case .integrationCourse: "Zertifikat Integrationskurs"
        case .pensionRecord: "Versicherungsverlauf (Rentenversicherung)"
        case .employmentContract: "Arbeitsvertrag"
        case .payslip: "Gehaltsabrechnung"
        case .taxAssessment: "Steuerbescheid"
        case .rentalContract: "Mietvertrag"
        case .residenceCard: "Aufenthaltstitel"
        case .passport: "Reisepass"
        case .degree: "Abschluss / Zeugnis"
        case .registration: "Meldebescheinigung"
        case .application: "Antrag"
        case .decision: "Bescheid"
        case .other: "Sonstiges"
        }
    }

    var english: String {
        switch self {
        case .languageCertificate: "language certificate"
        case .citizenshipTest: "citizenship or orientation test result"
        case .integrationCourse: "integration course certificate"
        case .pensionRecord: "pension insurance record"
        case .employmentContract: "employment contract"
        case .payslip: "payslip"
        case .taxAssessment: "tax assessment"
        case .rentalContract: "rental contract"
        case .residenceCard: "residence permit card"
        case .passport: "passport"
        case .degree: "degree or certificate"
        case .registration: "registration certificate"
        case .application: "application you submitted"
        case .decision: "decision from an authority"
        case .other: "other"
        }
    }

    var systemImage: String {
        switch self {
        case .languageCertificate: "character.book.closed"
        case .citizenshipTest, .integrationCourse: "checkmark.seal"
        case .pensionRecord: "chart.bar.doc.horizontal"
        case .employmentContract, .payslip, .taxAssessment: "briefcase"
        case .rentalContract: "house"
        case .residenceCard, .passport: "person.text.rectangle"
        case .degree: "graduationcap"
        case .registration: "mappin.and.ellipse"
        case .application, .decision: "envelope"
        case .other: "doc"
        }
    }

    /// Words in the official German text of a rule that suggest this kind of document is
    /// relevant to it. Matching on the law, not on the model's translation, works for every
    /// answer language.
    var lawTerms: [String] {
        switch self {
        case .languageCertificate: ["deutschen Sprache", "Sprachkenntnisse", "Sprachniveau", "Deutschkenntnisse"]
        case .citizenshipTest: ["Rechts- und Gesellschaftsordnung", "Einbürgerungstest", "Lebensverhältnisse"]
        case .integrationCourse: ["Integrationskurs", "Orientierungskurs"]
        case .pensionRecord: ["Rentenversicherung", "Pflichtbeiträge"]
        case .employmentContract: ["Beschäftigung", "Arbeitsplatz", "Arbeitgeber", "Erwerbstätigkeit"]
        case .payslip, .taxAssessment: ["Lebensunterhalt", "Gehalt", "öffentliche Mittel"]
        case .rentalContract: ["Wohnraum"]
        case .residenceCard: ["Aufenthaltserlaubnis", "Aufenthaltstitel", "Blaue Karte"]
        case .passport: ["Pass", "Passpflicht", "Identität", "Staatsangehörigkeit"]
        case .degree: ["Hochschulabschluss", "Berufsausbildung", "Qualifikation", "Studium"]
        case .registration: ["gewöhnlichen Aufenthalt", "rechtmäßigen Aufenthalt"]
        case .application, .decision, .other: []
        }
    }
}

struct DocumentRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var kind: DocumentKind
    /// Date on the document, e.g. when a certificate was issued. Optional.
    var issued: Date?
    var note = ""
    /// File name inside the documents folder.
    var storedFile: String
    var originalName: String
    var added = Date()
    /// True while the type is the app's own guess; false once the user has changed it.
    var autoSorted = true
    /// What the app read off the document, e.g. "Level B1".
    var detail: String?

    init(id: UUID = UUID(), title: String, kind: DocumentKind, issued: Date? = nil, note: String = "",
         storedFile: String, originalName: String) {
        self.id = id; self.title = title; self.kind = kind; self.issued = issued; self.note = note
        self.storedFile = storedFile; self.originalName = originalName
    }

    init(from decoder: any Decoder) throws {
        // Fields added later are optional here, so older lists still load.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        kind = (try? c.decode(DocumentKind.self, forKey: .kind)) ?? .other
        issued = try? c.decodeIfPresent(Date.self, forKey: .issued)
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        storedFile = try c.decode(String.self, forKey: .storedFile)
        originalName = (try? c.decode(String.self, forKey: .originalName)) ?? storedFile
        added = (try? c.decode(Date.self, forKey: .added)) ?? Date()
        autoSorted = (try? c.decode(Bool.self, forKey: .autoSorted)) ?? false
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
    }
}

/// The user's own documents, copied into the app's folder so they stay on this Mac and
/// are removed by "Delete everything".
@MainActor @Observable
final class DocumentStore {
    let directory: URL
    private(set) var records: [DocumentRecord] = []
    /// Documents being read right now, to show "Reading…" in the list.
    private(set) var sorting: Set<UUID> = []
    private var indexFile: URL { directory.appendingPathComponent("documents.json") }

    init(directory: URL) {
        self.directory = directory
        reload()
    }

    func reload() {
        guard let data = try? Data(contentsOf: indexFile) else { records = []; return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([DocumentRecord].self, from: data)) ?? []
    }

    func fileURL(for record: DocumentRecord) -> URL { directory.appendingPathComponent(record.storedFile) }

    /// Copies the file in. The original is left where it was.
    @discardableResult
    func add(_ url: URL, kind: DocumentKind? = nil) throws -> DocumentRecord {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        let stored = "\(id.uuidString).\(url.pathExtension.isEmpty ? "dat" : url.pathExtension)"
        try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(stored))
        try? (directory.appendingPathComponent(stored) as NSURL)
            .setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
        let name = url.deletingPathExtension().lastPathComponent
        var record = DocumentRecord(id: id, title: name, kind: kind ?? Self.guessKind(from: name), storedFile: stored,
                                    originalName: url.lastPathComponent)
        // A type the user chose when adding is theirs; only an automatic guess gets replaced.
        record.autoSorted = kind == nil
        records.insert(record, at: 0)
        save()
        sortAutomatically(record)
        return record
    }

    /// Reads the document on this Mac and sets its type, level and date, unless the user has
    /// already chosen them.
    func sortAutomatically(_ record: DocumentRecord) {
        let url = fileURL(for: record)
        sorting.insert(record.id)
        Task {
            let result = await Task.detached { await DocumentClassifier.classify(url) }.value
            sorting.remove(record.id)
            guard var current = records.first(where: { $0.id == record.id }) else { return }
            if current.autoSorted { current.kind = result.kind }
            current.detail = current.detail ?? result.detail
            if current.issued == nil { current.issued = result.issued }
            if let detail = result.detail, !current.title.contains(detail) { current.title += " (\(detail))" }
            update(current)
        }
    }

    func update(_ record: DocumentRecord) {
        guard let i = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[i] = record
        save()
    }

    func remove(_ record: DocumentRecord) {
        try? FileManager.default.removeItem(at: fileURL(for: record))
        records.removeAll { $0.id == record.id }
        save()
    }

    /// Documents whose kind relates to the official text of these citations.
    func related(to citations: [VerifiedCitation]) -> [DocumentRecord] {
        let text = citations.map(\.passage.paragraph.text).joined(separator: " ")
        return records.filter { record in record.kind.lawTerms.contains { text.localizedCaseInsensitiveContains($0) } }
    }

    nonisolated static func guessKind(from name: String) -> DocumentKind {
        let n = name.lowercased()
        let rules: [(DocumentKind, [String])] = [
            (.languageCertificate, ["telc", "goethe", "testdaf", "dtz", "b1", "b2", "c1", "sprach", "language", "ösd", "osd"]),
            (.citizenshipTest, ["einbürgerungstest", "leben in deutschland", "lid", "citizenship test"]),
            (.integrationCourse, ["integrationskurs", "integration"]),
            (.pensionRecord, ["rente", "versicherungsverlauf", "pension", "drv"]),
            (.payslip, ["gehalt", "lohn", "payslip", "entgelt", "abrechnung"]),
            (.taxAssessment, ["steuerbescheid", "steuer", "tax"]),
            (.employmentContract, ["arbeitsvertrag", "contract", "vertrag"]),
            (.rentalContract, ["miet", "rent", "lease"]),
            (.residenceCard, ["aufenthalt", "residence", "blue card", "blaue karte", "niederlassung"]),
            (.passport, ["pass", "passport"]),
            (.degree, ["zeugnis", "diploma", "degree", "bachelor", "master", "urkunde"]),
            (.registration, ["meldebescheinigung", "anmeldung", "registration"]),
            (.decision, ["bescheid", "decision"]),
            (.application, ["antrag", "application"]),
        ]
        return rules.first { _, words in words.contains { n.contains($0) } }?.0 ?? .other
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(records).write(to: indexFile, options: [.atomic, .completeFileProtection])
        } catch {
            // The list is rebuilt from what's on disk on the next launch.
        }
    }
}
