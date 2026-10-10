import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Metadata for one law in the official gesetze-im-internet.de XML.
public struct LawSource: Sendable, Hashable, Codable {
    /// Short name used in citations, e.g. "AufenthG".
    public var law: String
    /// URL slug on gesetze-im-internet.de, e.g. "aufenthg_2004".
    public var slug: String
    public var title: String

    public init(law: String, slug: String, title: String) {
        self.law = law
        self.slug = slug
        self.title = title
    }

    public var xmlZipURL: URL { URL(string: "https://www.gesetze-im-internet.de/\(slug)/xml.zip")! }

    public func sectionURL(_ number: String) -> URL {
        URL(string: "https://www.gesetze-im-internet.de/\(slug)/__\(number).html")!
    }

    /// The v1 scope (spec §8).
    public static let v1: [LawSource] = [
        LawSource(law: "AufenthG", slug: "aufenthg_2004", title: "Aufenthaltsgesetz"),
        LawSource(law: "StAG", slug: "stag", title: "Staatsangehörigkeitsgesetz"),
        LawSource(law: "BeschV", slug: "beschv_2013", title: "Beschäftigungsverordnung"),
        LawSource(law: "AufenthV", slug: "aufenthv", title: "Aufenthaltsverordnung"),
        LawSource(law: "FreizügG/EU", slug: "freiz_gg_eu_2004", title: "Freizügigkeitsgesetz/EU"),
    ]
}

/// Parses the official XML into sections and paragraphs, keeping the exact wording.
///
/// Only norms whose `enbez` is a single "§ N" are kept. Annexes, tables of contents
/// and repealed ranges ("§§ 1 bis 3") are skipped. Footnotes are dropped.
public enum LawXMLParser {
    public static func parse(data: Data, source: LawSource) throws -> [LawSection] {
        let delegate = Delegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return delegate.sections
    }

    public static func parse(fileAt url: URL, source: LawSource) throws -> [LawSection] {
        try parse(data: Data(contentsOf: url), source: source)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        let source: LawSource
        var sections: [LawSection] = []
        var asOf = Date(timeIntervalSince1970: 0)

        // State for the norm being read.
        var enbez = ""
        var titel = ""
        var paragraphs: [String] = []
        var stack: [String] = []
        var buffer = ""
        var pDepth = 0
        var skipDepth = 0

        init(source: LawSource) { self.source = source }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            stack.append(name)
            switch name {
            case "dokumente":
                if let build = attributes["builddate"] { asOf = Self.date(fromBuildDate: build) }
            case "norm":
                enbez = ""; titel = ""; paragraphs = []
            case "enbez", "titel":
                buffer = ""
            case "P" where inContent:
                if pDepth == 0 { buffer = "" }
                pDepth += 1
            case "FnR", "Footnotes" where pDepth > 0:
                skipDepth += 1
            case "DT", "DD", "LA", "BR", "entry", "row" where pDepth > 0:
                buffer += " "
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            defer { stack.removeLast() }
            switch name {
            case "enbez":
                enbez = Self.clean(buffer)
            case "titel" where stack.contains("metadaten"):
                titel = Self.clean(buffer)
            case "P" where pDepth > 0:
                pDepth -= 1
                if pDepth == 0 {
                    let text = Self.clean(buffer)
                    if !text.isEmpty { paragraphs.append(text) }
                }
            case "FnR", "Footnotes" where skipDepth > 0:
                skipDepth -= 1
            case "DT", "DD", "LA", "entry", "row" where pDepth > 0:
                buffer += " "
            case "norm":
                finishNorm()
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard skipDepth == 0 else { return }
            if pDepth > 0 || stack.last == "enbez" || stack.last == "titel" || stack.contains("titel") {
                buffer += string
            }
        }

        var inContent: Bool { stack.contains("Content") }

        func finishNorm() {
            guard enbez.hasPrefix("§ "), !enbez.hasPrefix("§§") else { return }
            let number = String(enbez.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let parsed = paragraphs.map { text -> LawParagraph in
                LawParagraph(number: Self.paragraphNumber(of: text), text: text)
            }
            sections.append(LawSection(
                law: source.law, number: number, heading: titel, paragraphs: parsed,
                sourceURL: source.sectionURL(number), asOf: asOf
            ))
        }

        static func paragraphNumber(of text: String) -> String? {
            guard let match = text.firstMatch(of: /^\((\d+[a-z]?)\)/) else { return nil }
            return String(match.1)
        }

        static func clean(_ s: String) -> String {
            s.replacingOccurrences(of: "\u{00A0}", with: " ")
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }

        static func date(fromBuildDate s: String) -> Date {
            // builddate is yyyyMMddHHmmss, German time.
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
            let digits = Array(s)
            func int(_ r: Range<Int>) -> Int { Int(String(digits[r])) ?? 0 }
            guard digits.count >= 8 else { return Date(timeIntervalSince1970: 0) }
            let components = DateComponents(year: int(0..<4), month: int(4..<6), day: int(6..<8))
            return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        }
    }
}
