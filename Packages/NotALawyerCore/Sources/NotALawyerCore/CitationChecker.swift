import Foundation

/// A citation that passed the check, resolved to the exact paragraph that contains the quote.
public struct VerifiedCitation: Sendable, Hashable, Codable {
    public var passage: LawPassage
    /// The quote as it appears in the official text.
    public var quote: String
    /// The model's translation of the quote. Always shown as a machine translation.
    public var translation: String?
    /// The model's one-sentence summary of the section. Shown as machine-written.
    public var about: String?
    /// False when the quote didn't match word for word, but the model named a paragraph it was
    /// given: the paragraph is shown without a highlight, labelled as such.
    public var quoteMatched = true

    public init(passage: LawPassage, quote: String, translation: String?, about: String?) {
        self.passage = passage
        self.quote = quote
        self.translation = translation
        self.about = about
    }

    public init(from decoder: any Decoder) throws {
        // Lenient, so chats saved before `quoteMatched` existed still load.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        passage = try c.decode(LawPassage.self, forKey: .passage)
        quote = try c.decode(String.self, forKey: .quote)
        translation = try? c.decodeIfPresent(String.self, forKey: .translation)
        about = try? c.decodeIfPresent(String.self, forKey: .about)
        quoteMatched = (try? c.decode(Bool.self, forKey: .quoteMatched)) ?? true
    }
}

/// Why a citation was removed. Kept for the evaluation's invented-fact rate.
public enum CitationRejection: Sendable, Hashable, Codable {
    case unknownSection(String)
    case quoteNotFound(String)
    case quoteTooShort(String)
}

/// Checks that each citation names a real section and quotes it verbatim (spec §6, step 3).
///
/// "Verbatim" ignores only differences that don't change wording: runs of whitespace,
/// typographic vs straight quotation marks and dashes, and leading or trailing
/// punctuation. A quote may skip text with "…" or "...", but every piece must appear,
/// in order, in one paragraph.
public struct CitationChecker: Sendable {
    public let index: LawIndex
    /// Quotes shorter than this many characters prove nothing and are removed.
    public var minimumQuoteLength = 12

    public init(index: LawIndex) { self.index = index }

    /// `given` are the passages the model was shown. A citation whose quote doesn't match exactly
    /// still counts, unhighlighted, if it names a paragraph from `given` and its quote shares most
    /// words with it: small models often paraphrase a word or two, and throwing those away turned
    /// correct answers into refusals.
    public func check(_ citations: [Citation], given: [LawPassage] = []) -> (verified: [VerifiedCitation], rejected: [CitationRejection]) {
        var verified: [VerifiedCitation] = []
        var rejected: [CitationRejection] = []
        for c in citations {
            let label = "§ \(c.section) \(c.law)"
            guard let section = index.section(law: c.law, number: Self.sectionNumber(c.section)) else {
                rejected.append(.unknownSection(label)); continue
            }
            let pieces = Self.pieces(of: c.quote)
            guard pieces.map(\.count).reduce(0, +) >= minimumQuoteLength else {
                rejected.append(.quoteTooShort(label)); continue
            }
            // Prefer the paragraph the model named; fall back to any paragraph of the section.
            let ordered = section.paragraphs.filter { $0.number == c.paragraph }
                + section.paragraphs.filter { $0.number != c.paragraph }
            guard let paragraph = ordered.first(where: { Self.contains(Self.normalize($0.text), inOrder: pieces) }) else {
                if let near = ordered.first(where: { p in
                    given.contains { $0.section.label == section.label && $0.paragraph.number == p.number }
                        && Self.wordOverlap(c.quote, p.text) >= 0.7
                }) {
                    var v = VerifiedCitation(passage: LawPassage(section: section, paragraph: near), quote: c.quote,
                                             translation: c.translation, about: c.about)
                    v.quoteMatched = false
                    verified.append(v)
                } else {
                    rejected.append(.quoteNotFound(label))
                }
                continue
            }
            let passage = LawPassage(section: section, paragraph: paragraph)
            guard !verified.contains(where: { $0.passage == passage && $0.quote == c.quote }) else { continue }
            verified.append(VerifiedCitation(passage: passage, quote: c.quote.trimmingCharacters(in: .whitespacesAndNewlines),
                                             translation: c.translation, about: c.about))
        }
        return (verified, rejected)
    }

    /// Where a verified quote sits in `text`, one range per piece, for highlighting.
    public static func ranges(of quote: String, in text: String) -> [Range<String.Index>] {
        // normalize() swaps single characters and collapses whitespace; paragraph text is
        // already collapsed, so character offsets in the normalized text match `text`.
        let normalized = normalize(text)
        guard normalized.count == text.count else { return [] }
        var result: [Range<String.Index>] = []
        var searchStart = normalized.startIndex
        for piece in pieces(of: quote) {
            guard let r = normalized.range(of: piece, range: searchStart..<normalized.endIndex) else { return [] }
            let lower = normalized.distance(from: normalized.startIndex, to: r.lowerBound)
            let length = normalized.distance(from: r.lowerBound, to: r.upperBound)
            let start = text.index(text.startIndex, offsetBy: lower)
            result.append(start..<text.index(start, offsetBy: length))
            searchStart = r.upperBound
        }
        return result
    }

    /// Share of the quote's words (4+ letters) that appear in the paragraph.
    static func wordOverlap(_ quote: String, _ text: String) -> Double {
        let words = { (s: String) in Set(s.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { $0.count >= 4 }) }
        let q = words(quote)
        guard q.count >= 4 else { return 0 }
        return Double(q.intersection(words(text)).count) / Double(q.count)
    }

    /// "9", "§ 9", "9 Abs. 2" → "9".
    static func sectionNumber(_ s: String) -> String {
        s.firstMatch(of: /(\d+[a-z]?)/).map { String($0.1) } ?? s
    }

    static func pieces(of quote: String) -> [String] {
        // A leading "(2)" is the paragraph's label, not its wording; models often get it wrong.
        normalize(quote).replacing(/^\(\d+[a-z]?\)\s*/, with: "")
            .replacingOccurrences(of: "...", with: "…")
            .split(separator: "…")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }
    }

    static func contains(_ text: String, inOrder pieces: [String]) -> Bool {
        guard !pieces.isEmpty else { return false }
        var rest = text[...]
        for piece in pieces {
            guard let range = rest.range(of: piece) else { return false }
            rest = rest[range.upperBound...]
        }
        return true
    }

    static func normalize(_ s: String) -> String {
        var out = s
        for (from, to) in [("„", "\""), ("“", "\""), ("”", "\""), ("‚", "'"), ("‘", "'"), ("’", "'"),
                           ("–", "-"), ("—", "-"), ("\u{00A0}", " ")] {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
