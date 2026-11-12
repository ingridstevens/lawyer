import Foundation

/// Something in a letter from an authority that the reader must be able to check with their own
/// eyes: a date, a deadline, an amount, a reference number or a law it cites. Found by rules, not
/// by a model, so nothing is invented, and each fact keeps the exact words it was found in.
public struct LetterFact: Identifiable, Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        /// A date the reader must do something by ("bis zum 15.01.2027").
        case deadline
        /// A time span instead of a date ("innerhalb eines Monats nach Bekanntgabe").
        case period
        /// A date to be somewhere ("Termin am 03.02.2027 um 9:30 Uhr").
        case appointment
        case date
        case amount
        case reference
        case law
    }

    public var kind: Kind
    /// Exactly as printed, e.g. "15.01.2027" or "§ 9 Abs. 2 AufenthG".
    public var text: String
    /// Where `text` sits in the letter's text.
    public var range: Range<String.Index>
    /// The line it was found on, counted from 0.
    public var line: Int
    /// The whole line, so the reader sees the fact in its own words.
    public var snippet: String
    /// A reference number without its label, a law's abbreviation, or a date as yyyy-MM-dd.
    public var value: String
    /// Why this fact needs a second look, e.g. a date that doesn't exist.
    public var warning: String?
    /// Character offset in the letter's text; unique, because facts never overlap.
    public var id: Int
}

public enum LetterFacts {
    /// Finds the facts in a letter's text, in reading order.
    /// - Parameter coveredLaws: the laws the app can quote. A cited law outside them is flagged.
    public static func find(in text: String, coveredLaws: Set<String> = []) -> [LetterFact] {
        var candidates: [(LetterFact.Kind, Range<String.Index>, String, String?)] = []

        for m in text.matches(of: lawReference) {
            let law = String(m.output.2)
            let warning = coveredLaws.isEmpty || coveredLaws.contains(law) ? nil
                : "\(law) isn't one of the laws this app covers, so it can't quote or explain it."
            candidates.append((.law, m.range, law, warning))
        }
        for m in text.matches(of: reference) {
            guard let value = referenceValue(m.output.2), value.contains(where: \.isNumber) else { continue }
            candidates.append((.reference, value.startIndex..<value.endIndex, String(value), nil))
        }
        for m in text.matches(of: amount) {
            candidates.append((.amount, m.range, String(m.output.1 ?? m.output.2 ?? ""), nil))
        }
        for m in text.matches(of: period) {
            candidates.append((.period, m.range, "",
                               "The letter gives a time span, not a date. When it starts depends on when the letter reached you. A free counsellor can work out the date with you."))
        }
        for m in text.matches(of: numericDate) {
            guard let day = Int(m.output.1), let month = Int(m.output.2), var year = Int(m.output.3) else { continue }
            if m.output.3.count == 2 { year += 2000 }
            candidates.append(date(day: day, month: month, year: year, range: m.range, in: text))
        }
        for m in text.matches(of: writtenDate) {
            guard let day = Int(m.output.1), let year = Int(m.output.3),
                  let month = months.firstIndex(where: { $0.contains(m.output.2.lowercased()) }) else { continue }
            candidates.append(date(day: day, month: month + 1, year: year, range: m.range, in: text))
        }

        // Earliest first; where two overlap, the longer one wins (a date inside a reference number).
        candidates.sort { a, b in
            a.1.lowerBound != b.1.lowerBound ? a.1.lowerBound < b.1.lowerBound : a.1.upperBound > b.1.upperBound
        }
        let lineStarts = [text.startIndex] + text.indices.filter { text[$0] == "\n" }.map { text.index(after: $0) }
        var facts: [LetterFact] = []
        for (kind, range, value, warning) in candidates {
            if let last = facts.last, range.lowerBound < last.range.upperBound { continue }
            let line = lineStarts.lastIndex { $0 <= range.lowerBound } ?? 0
            let lineEnd = text[range.lowerBound...].firstIndex(of: "\n") ?? text.endIndex
            facts.append(LetterFact(
                kind: kind, text: String(text[range]), range: range, line: line,
                snippet: text[lineStarts[line]..<lineEnd].trimmingCharacters(in: .whitespaces),
                value: value, warning: warning, id: text.distance(from: text.startIndex, to: range.lowerBound)))
        }
        return facts
    }

    // MARK: Dates

    /// Decides from the words around a date whether it's a deadline or an appointment. It never
    /// works a date out; it only labels a date that is printed.
    private static func date(day: Int, month: Int, year: Int, range: Range<String.Index>, in text: String)
        -> (LetterFact.Kind, Range<String.Index>, String, String?) {
        let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let before = text[lineStart..<range.lowerBound].suffix(50).lowercased()
        let after = text[range.upperBound...].prefix(30).lowercased()
        // "gültig vom 01.01.2026 bis 31.12.2026" is a span, not a deadline.
        let isSpan = before.contains(/\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}\s*(bis|-|–)\s*$/)
        let kind: LetterFact.Kind =
            !isSpan && ["bis zum", "bis spätestens", "spätestens", "frist", "bis "].contains(where: { before.contains($0) }) ? .deadline
            : ["termin", "vorsprache", "vorzusprechen", "erscheinen"].contains(where: { before.contains($0) })
                || after.contains(/^\s*,?\s*(um\s+)?\d{1,2}[:.]\d{2}\s*uhr/) ? .appointment
            : .date
        let components = DateComponents(calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day)
        guard components.isValidDate else {
            return (kind, range, "", "This date doesn't exist, so it was probably read wrongly. Check it on the letter.")
        }
        return (kind, range, String(format: "%04d-%02d-%02d", year, month, day), nil)
    }

    private static let months = [["januar", "jänner"], ["februar"], ["märz", "maerz"], ["april"], ["mai"], ["juni"],
                                 ["juli"], ["august"], ["september"], ["oktober"], ["november"], ["dezember"]]

    // Regexes are never changed after they're made, so sharing them across threads is safe.
    /// 15.01.2027, 15. 1. 2027, 15.01.27
    nonisolated(unsafe) private static let numericDate = /\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4}|\d{2})\b/
    /// 15. Januar 2027
    nonisolated(unsafe) private static let writtenDate =
        /\b(\d{1,2})\.\s?(Januar|Jänner|Februar|März|Maerz|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)\s+(\d{4})\b/

    /// innerhalb eines Monats nach Bekanntgabe dieses Bescheides; binnen zwei Wochen
    nonisolated(unsafe) private static let period =
        /(?i)(?:innerhalb|binnen)\s+(?:von\s+)?(?:eines|einem|einer|eine|zwei|drei|vier|sechs|acht|zehn|vierzehn|\d+)\s+(?:Monats|Monaten|Monat|Wochen|Woche|Tagen|Tage|Tag)\b(?:\s+(?:nach|ab|seit)\s+(?:der\s+|dem\s+)?(?:Bekanntgabe|Zustellung|Erhalt|Zugang)(?:\s+(?:dieses|des|dieser|der)\s+(?:Bescheides|Bescheids|Schreibens|Entscheidung))?)?/

    // MARK: Amounts, references, laws

    /// 1.234,56 €, 100 EUR, € 55,00, 50 Euro
    nonisolated(unsafe) private static let amount =
        /(?:(?:€|EUR)\s?(\d{1,3}(?:\.\d{3})+(?:,\d{2})?|\d+(?:,\d{2})?)\b)|(?:\b(\d{1,3}(?:\.\d{3})+(?:,\d{2})?|\d+(?:,\d{2})?)\s?(?:€|EUR\b|Euro\b))/

    /// "Aktenzeichen: 12-345/AB", "Az.: …", "Unser Zeichen …"
    nonisolated(unsafe) private static let reference =
        /(?i)\b(Aktenzeichen|Az\.|Az:|Geschäftszeichen|Gesch\.-Z\.|Unser Zeichen|Ihr Zeichen|Kundennummer|Vorgangsnummer|Bearbeitungsnummer|Antragsnummer)\s*[:.]?[ \t]*([^\n,;]{2,40})/

    /// The number itself: up to the end of the line, or to a wide gap before the next column.
    private static func referenceValue(_ raw: Substring) -> Substring? {
        var value = raw
        if let gap = value.firstRange(of: /\s{2,}|\t/) { value = value[..<gap.lowerBound] }
        while let first = value.first, first.isWhitespace { value = value.dropFirst() }
        while let last = value.last, last.isWhitespace || last == "." { value = value.dropLast() }
        return value.isEmpty ? nil : value
    }

    /// § 9 AufenthG, § 81 Abs. 4 Satz 1 AufenthG, §§ 10 StAG. The abbreviation needs two capitals,
    /// so "§ 9 Die …" isn't read as a law.
    nonisolated(unsafe) private static let lawReference =
        /§§?\s*(\d+[a-z]?)(?:\s*(?:Abs\.|Absatz)\s*\d+[a-z]?)?(?:\s*(?:S\.|Satz)\s*\d+)?(?:\s*(?:Nr\.|Nummer)\s*\d+[a-z]?)?\s*(?:des\s+|der\s+)?([A-ZÄÖÜ][A-Za-zÄÖÜäöü]*[A-ZÄÖÜ][A-Za-zÄÖÜäöü]*(?:\/EU)?)/
}
