import Testing
@testable import NotALawyerCore

/// A made-up letter: no real person, office or case.
let sampleLetter = """
Stadt Musterstadt – Ausländerbehörde
Musterstraße 1, 12345 Musterstadt
Aktenzeichen: 32.1-ABC/4711          Datum: 02.11.2026

Antrag auf Erteilung einer Niederlassungserlaubnis nach § 9 Abs. 2 AufenthG

Sehr geehrte Frau Beispiel,
bitte reichen Sie die folgenden Unterlagen bis zum 15.12.2026 ein.
Ihr Termin zur Vorsprache ist am 3. Februar 2027 um 9:30 Uhr.
Die Gebühr beträgt 113,00 € (§ 45 AufenthV).
Ihre Fiktionsbescheinigung ist gültig vom 01.11.2026 bis 30.04.2027.
Nach § 40 VwVfG entscheidet die Behörde nach Ermessen.

Rechtsbehelfsbelehrung: Gegen diesen Bescheid kann innerhalb eines Monats nach Bekanntgabe Klage erhoben werden.
"""

@Suite struct LetterFactsTests {
    let facts = LetterFacts.find(in: sampleLetter, coveredLaws: ["AufenthG", "AufenthV", "BeschV", "FreizügG/EU", "StAG"])

    func fact(_ text: String) -> LetterFact? { facts.first { $0.text == text } }

    @Test func findsTheReferenceNumberWithoutItsLabelOrTheNextColumn() throws {
        let az = try #require(facts.first { $0.kind == .reference })
        #expect(az.text == "32.1-ABC/4711")
        #expect(az.snippet.hasPrefix("Aktenzeichen: 32.1-ABC/4711"))
        #expect(az.line == 2)
    }

    @Test func labelsDeadlinesAppointmentsAndPlainDates() {
        #expect(fact("15.12.2026")?.kind == .deadline)
        #expect(fact("15.12.2026")?.value == "2026-12-15")
        #expect(fact("3. Februar 2027")?.kind == .appointment)
        #expect(fact("3. Februar 2027")?.value == "2027-02-03")
        #expect(fact("02.11.2026")?.kind == .date)
    }

    @Test func aValidityRangeIsNotADeadline() {
        #expect(fact("01.11.2026")?.kind == .date)
        #expect(fact("30.04.2027")?.kind == .date)
    }

    @Test func aTimeSpanIsKeptAsWrittenNotTurnedIntoADate() throws {
        let period = try #require(facts.first { $0.kind == .period })
        #expect(period.text == "innerhalb eines Monats nach Bekanntgabe")
        #expect(period.warning != nil)
    }

    @Test func amounts() {
        #expect(fact("113,00 €")?.kind == .amount)
        #expect(fact("113,00 €")?.value == "113,00")
        let other = LetterFacts.find(in: "Bitte zahlen Sie EUR 1.250,50 oder 50 Euro.")
        #expect(other.map(\.text) == ["EUR 1.250,50", "50 Euro"])
    }

    @Test func lawsOutsideTheCoveredOnesAreFlagged() {
        #expect(fact("§ 9 Abs. 2 AufenthG")?.value == "AufenthG")
        #expect(fact("§ 9 Abs. 2 AufenthG")?.warning == nil)
        #expect(fact("§ 45 AufenthV")?.warning == nil)
        #expect(fact("§ 40 VwVfG")?.warning?.contains("isn't one of the laws") == true)
    }

    @Test func impossibleDatesAreFlaggedNotFixed() throws {
        let f = try #require(LetterFacts.find(in: "Frist bis zum 31.02.2027.").first)
        #expect(f.text == "31.02.2027")
        #expect(f.kind == .deadline)
        #expect(f.value.isEmpty)
        #expect(f.warning != nil)
    }

    @Test func factsAreInReadingOrderAndNeverOverlap() {
        for (a, b) in zip(facts, facts.dropFirst()) {
            #expect(a.range.upperBound <= b.range.lowerBound)
        }
        #expect(Set(facts.map(\.id)).count == facts.count)
    }

    @Test func plainTextHasNoFacts() {
        #expect(LetterFacts.find(in: "Sehr geehrte Damen und Herren, vielen Dank.").isEmpty)
    }
}
