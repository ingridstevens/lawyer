import Foundation

/// One paragraph (Abs.) of a section, with its exact official wording.
public struct LawParagraph: Sendable, Hashable, Codable {
    /// "1", "3a", or nil when the section has no numbered paragraphs.
    public var number: String?
    public var text: String

    public init(number: String?, text: String) {
        self.number = number
        self.text = text
    }
}

/// One section (§) of a law, with its wording kept exactly as published (spec §8).
public struct LawSection: Sendable, Hashable, Codable {
    /// Short name of the law, e.g. "AufenthG".
    public var law: String
    /// Section number as printed, e.g. "9" or "18a".
    public var number: String
    public var heading: String
    public var paragraphs: [LawParagraph]
    public var sourceURL: URL
    /// Date of the law version this text comes from.
    public var asOf: Date

    public init(law: String, number: String, heading: String, paragraphs: [LawParagraph], sourceURL: URL, asOf: Date) {
        self.law = law
        self.number = number
        self.heading = heading
        self.paragraphs = paragraphs
        self.sourceURL = sourceURL
        self.asOf = asOf
    }

    /// The heading, or the law's full name for laws without headings (StAG has none).
    public var displayHeading: String {
        heading.isEmpty ? (LawSource.v1.first { $0.law == law }?.title ?? law) : heading
    }

    /// Citation label, e.g. "§ 9 AufenthG".
    public var label: String { "§ \(number) \(law)" }

    public var fullText: String { paragraphs.map(\.text).joined(separator: " ") }
}

/// A paragraph together with the section it belongs to: the unit retrieval returns.
public struct LawPassage: Sendable, Hashable, Codable {
    public var section: LawSection
    public var paragraph: LawParagraph

    public init(section: LawSection, paragraph: LawParagraph) {
        self.section = section
        self.paragraph = paragraph
    }

    /// e.g. "§ 9 Abs. 2 AufenthG".
    public var label: String {
        guard let number = paragraph.number else { return section.label }
        return "§ \(section.number) Abs. \(number) \(section.law)"
    }
}
