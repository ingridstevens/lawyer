import Foundation
import Testing
@testable import NotALawyerCore

/// The bundled snapshot in data/snapshot at the repo root.
let snapshotDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("data/snapshot")

let index = try! LawIndex(directory: snapshotDirectory)

@Suite struct ParserTests {
    @Test func loadsAllFiveLaws() {
        #expect(index.laws == ["AufenthG", "AufenthV", "BeschV", "FreizügG/EU", "StAG"])
    }

    @Test func parsesSectionNinePreservingWording() throws {
        let s = try #require(index.section(law: "AufenthG", number: "9"))
        #expect(s.heading == "Niederlassungserlaubnis")
        #expect(s.paragraphs.first?.number == "1")
        #expect(s.paragraphs.first?.text.hasPrefix("(1) Die Niederlassungserlaubnis ist ein unbefristeter Aufenthaltstitel.") == true)
        let abs2 = try #require(s.paragraphs.first { $0.number == "2" })
        #expect(abs2.text.contains("1. er seit fünf Jahren die Aufenthaltserlaubnis besitzt, 2. sein Lebensunterhalt gesichert ist,"))
        #expect(s.sourceURL.absoluteString == "https://www.gesetze-im-internet.de/aufenthg_2004/__9.html")
    }

    @Test func lettersInSectionNumbers() {
        #expect(index.section(law: "AufenthG", number: "18a") != nil)
        #expect(index.section(law: "AufenthG", number: "18A") != nil)
    }

    @Test func labels() throws {
        let s = try #require(index.section(law: "AufenthG", number: "9"))
        #expect(s.label == "§ 9 AufenthG")
        #expect(LawPassage(section: s, paragraph: s.paragraphs[1]).label == "§ 9 Abs. 2 AufenthG")
    }
}

@Suite struct SearchTests {
    @Test func findsSettlementPermit() {
        let hits = index.search(terms: ["Niederlassungserlaubnis"], limit: 10)
        #expect(hits.contains { $0.section.label == "§ 9 AufenthG" })
    }

    @Test func prefixMatchesCompounds() {
        let hits = index.search(terms: ["Einbürgerung"], limit: 10)
        #expect(hits.contains { $0.section.law == "StAG" })
    }

    @Test func profileBoostPullsLawUp() {
        let plain = index.search(terms: ["Daueraufenthalt"], limit: 5)
        let boosted = index.search(terms: ["Daueraufenthalt"], lawBoost: ["FreizügG/EU": 10], limit: 5)
        #expect(boosted.first?.section.law == "FreizügG/EU")
        #expect(plain.map(\.section.law) != boosted.map(\.section.law))
    }

    @Test func referencedSectionsInQuestion() {
        #expect(index.referencedSections(in: "What does § 10 StAG say?").map(\.label) == ["§ 10 StAG"])
        #expect(index.referencedSections(in: "Was regelt §18a?").contains { $0.label == "§ 18a AufenthG" })
    }

    @Test func queryEscapesQuotes() {
        #expect(LawIndex.ftsQuery(["Blaue Karte EU", "Visum\"", "ab"]) == "\"Blaue Karte EU\" OR \"Visum\"*")
    }
}

@Suite struct CitationCheckerTests {
    let checker = CitationChecker(index: index)

    @Test func acceptsVerbatimQuote() {
        let c = Citation(law: "AufenthG", section: "9", paragraph: "1", quote: "Die Niederlassungserlaubnis ist ein unbefristeter Aufenthaltstitel.")
        #expect(checker.check([c]).verified.count == 1)
    }

    @Test func toleratesWhitespaceAndWrongParagraph() {
        let c = Citation(law: "AufenthG", section: "§ 9", paragraph: "4", quote: "sein  Lebensunterhalt\ngesichert ist")
        let result = checker.check([c])
        #expect(result.verified.first?.passage.paragraph.number == "2")
    }

    @Test func acceptsEllipsisWhenPiecesAreInOrder() {
        let c = Citation(law: "AufenthG", section: "9", quote: "Einem Ausländer ist die Niederlassungserlaubnis zu erteilen, wenn … sein Lebensunterhalt gesichert ist")
        #expect(checker.check([c]).verified.count == 1)
    }

    @Test func rejectsReworded() {
        let c = Citation(law: "AufenthG", section: "9", quote: "Die Niederlassungserlaubnis ist ein unbefristeter Titel.")
        #expect(checker.check([c]).rejected == [.quoteNotFound("§ 9 AufenthG")])
    }

    @Test func rejectsInventedSection() {
        let c = Citation(law: "AufenthG", section: "999", quote: "Die Niederlassungserlaubnis ist ein unbefristeter Aufenthaltstitel.")
        #expect(checker.check([c]).rejected == [.unknownSection("§ 999 AufenthG")])
    }

    @Test func rejectsQuoteFromAnotherSection() {
        let c = Citation(law: "AufenthG", section: "10", quote: "Die Niederlassungserlaubnis ist ein unbefristeter Aufenthaltstitel.")
        #expect(checker.check([c]).verified.isEmpty)
    }

    @Test func rejectsTrivialQuote() {
        let c = Citation(law: "AufenthG", section: "9", quote: "Ausländer")
        #expect(checker.check([c]).rejected == [.quoteTooShort("§ 9 AufenthG")])
    }
}

@Suite struct LocalhostRuleTests {
    @Test func allowsOnlyThisComputer() {
        #expect(LocalServerProvider.isLocal(URL(string: "http://localhost:11434")!))
        #expect(LocalServerProvider.isLocal(URL(string: "http://127.0.0.1:1234/v1")!))
        #expect(LocalServerProvider.isLocal(URL(string: "http://[::1]:8080/v1")!))
        #expect(!LocalServerProvider.isLocal(URL(string: "http://192.168.1.5:11434")!))
        #expect(!LocalServerProvider.isLocal(URL(string: "https://api.openai.com/v1")!))
        #expect(!LocalServerProvider.isLocal(URL(string: "http://localhost.evil.com")!))
    }

    @Test func refusesRemoteServer() {
        #expect(throws: LocalServerError.self) {
            try LocalServerProvider(kind: .openAICompatible, baseURL: URL(string: "http://10.0.0.2:8080/v1")!, model: "x")
        }
    }
}

@Suite struct QueryExpansionTests {
    @Test func mapsEverydayWordsInSeveralLanguages() {
        #expect(QueryExpansion.terms(for: "How do I get permanent residence?").contains("Niederlassungserlaubnis"))
        #expect(QueryExpansion.terms(for: "Как получить гражданство?").contains("Einbürgerung"))
        #expect(QueryExpansion.terms(for: "Eşimi getirebilir miyim? Aile birleşimi").contains("Familiennachzug"))
    }
}

@Suite struct CitationMarkerTests {
    @Test func ignoresWrongParagraphLabelInQuote() {
        let c = Citation(law: "AufenthG", section: "9", paragraph: "2", quote: "(1) Einem Ausländer ist die Niederlassungserlaubnis zu erteilen, wenn")
        #expect(CitationChecker(index: index).check([c]).verified.first?.passage.paragraph.number == "2")
    }
}

@Suite struct HighlightRangeTests {
    @Test func findsQuotePiecesInParagraph() throws {
        let text = try #require(index.section(law: "AufenthG", number: "9")?.paragraphs[1].text)
        let ranges = CitationChecker.ranges(of: "Einem Ausländer ist die Niederlassungserlaubnis zu erteilen, wenn … sein Lebensunterhalt gesichert ist", in: text)
        #expect(ranges.map { String(text[$0]) } == ["Einem Ausländer ist die Niederlassungserlaubnis zu erteilen, wenn", "sein Lebensunterhalt gesichert ist"])
    }
}

@Suite struct PlanTests {
    /// Every paragraph a plan cites must exist, so a law update that renumbers one fails here.
    @Test(arguments: Plan.all)
    func everyReferenceExists(_ plan: Plan) {
        for step in plan.steps {
            for ref in step.refs {
                let section = index.section(law: ref.law, number: ref.section)
                #expect(section != nil, "\(plan.id)/\(step.id): \(ref.label) not found")
                if let paragraph = ref.paragraph, let section {
                    #expect(section.paragraphs.contains { $0.number == paragraph }, "\(plan.id)/\(step.id): \(ref.label) not found")
                }
            }
        }
    }

    @Test func stepIDsAreUniqueWithinAPlan() {
        for plan in Plan.all { #expect(Set(plan.steps.map(\.id)).count == plan.steps.count) }
    }

    @Test func blueCardHoldersSeeTheBlueCardPlanFirst() {
        let s = Situation(status: .blueCard, goals: [.permanentResidence])
        #expect(Plan.suggested(for: s).first?.id == "settlement-bluecard")
    }
}

@Suite struct ApplicationRefTests {
    @Test(arguments: Situation.Application.allCases)
    func referenceExists(_ application: Situation.Application) {
        #expect(index.section(law: application.ref.law, number: application.ref.section) != nil, "\(application.ref.label)")
    }

    @Test func oldSettingsWithUnknownValuesStillLoad() throws {
        let json = #"{"goals":["citizenship","somethingRemoved"],"pendingApplications":["extension"],"countryCode":"TR"}"#
        let s = try JSONDecoder().decode(Situation.self, from: Data(json.utf8))
        #expect(s.goals == [.citizenship])
        #expect(s.pendingApplications.isEmpty)
        #expect(s.countryCode == "TR")
    }
}

@Suite struct NetworkPolicyTests {
    @Test func allowsOnlyThisMacAndTheLawSite() {
        #expect(NetworkPolicy.isAllowed(URL(string: "http://localhost:11434/api/chat")!))
        #expect(NetworkPolicy.isAllowed(URL(string: "http://127.0.0.1:1234/v1/models")!))
        #expect(NetworkPolicy.isAllowed(URL(string: "https://www.gesetze-im-internet.de/stag/xml.zip")!))
        #expect(!NetworkPolicy.isAllowed(URL(string: "http://www.gesetze-im-internet.de/stag/xml.zip")!))
        #expect(!NetworkPolicy.isAllowed(URL(string: "https://api.openai.com/v1/chat")!))
        #expect(!NetworkPolicy.isAllowed(URL(string: "https://ollama.com/library")!))
        #expect(!NetworkPolicy.isAllowed(URL(string: "https://gesetze-im-internet.de.evil.com/")!))
    }

    @Test func blockedRequestsThrowAndAreLogged() {
        #expect(throws: NetworkPolicyError.self) { try NetworkPolicy.check(URL(string: "https://example.com")!, purpose: "test") }
        #expect(NetworkPolicy.log.first { $0.host == "example.com" }?.allowed == false)
    }
}

@Suite struct TopicNoteTests {
    @Test func dualNationalityQuestionGetsTheNote() {
        #expect(TopicNote.matching("can i keep my current citizenship if my application succeeds?").map(\.id) == ["multiple-nationality"])
    }

    @Test(arguments: TopicNote.all)
    func everyReferenceExists(_ note: TopicNote) {
        for ref in note.sections {
            let section = index.section(law: ref.law, number: ref.section)
            #expect(section?.paragraphs.contains { $0.number == ref.paragraph } == true, "\(ref.label)")
        }
    }
}

@Suite struct SchemaTests {
    @Test func schemasAreValidJSONWithExplanationFirst() throws {
        for schema in [Prompts.answerJSONSchema, Prompts.planJSONSchema] {
            #expect(throws: Never.self) { try JSONSerialization.jsonObject(with: Data(schema.utf8)) }
        }
        let a = Prompts.answerJSONSchema
        #expect(a.range(of: "\"explanation\"")!.lowerBound < a.range(of: "\"citations\"")!.lowerBound)
        #expect(a.range(of: "\"citations\"")!.lowerBound < a.range(of: "\"refused\"")!.lowerBound)
    }
}

@Suite struct RegressionTests {
    struct Budget: ModelProvider {
        var displayName: String { "budget" }
        var contextBudget: Int { 7_000 }
        func plan(_ question: String) async throws -> QueryPlan { QueryPlan(route: .law) }
        func answer(_ request: AnswerRequest) async throws -> ModelAnswer { fatalError() }
    }

    /// Crashed: the planner suggested "§ 12", which matches the repealed, empty § 12 StAG.
    @Test func suggestedRepealedSectionDoesNotCrash() {
        let engine = AnswerEngine(index: index, provider: Budget())
        let suggested = index.referencedSections(in: "§ 10 § 11 § 12")
        #expect(suggested.contains { $0.paragraphs.isEmpty })
        _ = engine.retrieve(question: "How long can I leave Germany without losing my residence permit?",
                            terms: ["Ausland"], situation: Situation(), suggested: suggested)
    }
}

@Suite struct PersonaFindingsTests {
    @Test func turkishCitizenshipWordFormsFindStAG() {
        #expect(QueryExpansion.terms(for: "3 yıl sonra Alman vatandaşlığına başvurabilir miyim?").contains("Einbürgerung"))
    }

    @Test func staysAbroadGetsTheNote() {
        #expect(TopicNote.matching("If I study in Spain for a year, will I lose my residence permit?").map(\.id).contains("stays-abroad"))
        #expect(TopicNote.matching("İspanya'da bir yıl okursam oturma iznimi kaybeder miyim?").map(\.id).contains("stays-abroad"))
        #expect(TopicNote.matching("Türk vatandaşlığımı koruyabilir miyim?").map(\.id).contains("multiple-nationality"))
    }

    @Test func verdictsAreFlagged() {
        let a = ModelAnswer(explanation: "You cannot get a Niederlassungserlaubnis before leaving Germany.", conditions: [], citations: [], refused: false)
        #expect(!AnswerChecks.verdictPhrases(in: a).isEmpty)
        let b = ModelAnswer(explanation: "The law says a settlement permit is granted when five conditions are met.", conditions: [], citations: [], refused: false)
        #expect(AnswerChecks.verdictPhrases(in: b).isEmpty)
    }

    @Test func leakedJSONAndDuplicatesAreRemovedFromChecklists() {
        #expect(AnswerChecks.cleanConditions(["B1 German", "b1 german", "citations': [{", " "]) == ["B1 German"])
    }
}

@Suite struct MixedQuestionTests {
    @Test func citizenshipQuestionNamingAnotherCountryGetsTheNationalityNote() {
        let q = "If I have Canadian citizenship, what do I do if I want to get German citizenship, and do I keep filing taxes at home?"
        #expect(TopicNote.matching(q).map(\.id).contains("multiple-nationality"))
    }

    @Test func plainCitizenshipQuestionDoesNot() {
        #expect(!TopicNote.matching("After how many years can I apply for German citizenship?").map(\.id).contains("multiple-nationality"))
    }
}

@Suite struct SituationVerdictTests {
    /// Seen in the app on 1 Oct 2026: the model used the user's nationality to decide for them.
    @Test func applyingTheRuleToTheUserIsFlagged() {
        let a = ModelAnswer(explanation: "This rule applies to people like you, as your nationality (Canada) means you are outside the European Union.",
                            conditions: [], citations: [], refused: false)
        #expect(!AnswerChecks.verdictPhrases(in: a).isEmpty)
    }
}

@Suite struct PlanStepKindTests {
    @Test func applyingIsAnActionNotACondition() {
        for plan in Plan.all {
            if let apply = plan.steps.first(where: { $0.id == "apply" }) { #expect(apply.kind == .action, "\(plan.id)") }
            #expect(plan.steps.filter { $0.id != "apply" }.allSatisfy { $0.kind == .condition }, "\(plan.id)")
        }
    }
}

@Suite struct SavedAnswerTests {
    /// Chats are saved as JSON; an answer must read back exactly, quotes and dates included.
    @Test func answerSurvivesSaving() throws {
        let section = try #require(index.section(law: "StAG", number: "10"))
        let passage = LawPassage(section: section, paragraph: section.paragraphs[0])
        var answer = Answer(question: "After how many years?", explanation: "Five.", conditions: ["Five years"],
                            citations: [VerifiedCitation(passage: passage, quote: "seit fünf Jahren", translation: "for five years", about: "Naturalisation")],
                            refused: false, closest: [], plan: QueryPlan(route: .law, terms: ["Einbürgerung"]),
                            searchTerms: ["Einbürgerung"], retrieved: [passage], rejected: [.quoteNotFound("§ 9 StAG")], raw: nil)
        answer.topicNotes = [TopicNote.multipleNationality]
        let decoded = try JSONDecoder().decode(Answer.self, from: JSONEncoder().encode(answer))
        #expect(decoded.citations == answer.citations)
        #expect(decoded.topicNotes == answer.topicNotes)
        #expect(decoded.rejected == answer.rejected)
        #expect(decoded.citations.first?.passage.section.asOf == section.asOf)
    }
}

@Suite struct SharedConditionTests {
    @Test func b1IsTheSameConditionInEveryPlanThatHasIt() {
        let b1 = Plan.citizenship.steps.first { $0.id == "language" }!
        #expect(Set(Plan.sameCondition(as: b1).map(\.plan.id)) == ["citizenship", "settlement", "settlement-skilled", "eu-longterm"])
    }

    @Test func everySharedKeyLinksAtLeastTwoPlans() {
        let keys = Set(Plan.all.flatMap(\.steps).compactMap(\.shared))
        for key in keys {
            #expect(Set(Plan.all.filter { $0.steps.contains { $0.shared == key } }.map(\.id)).count >= 2, "\(key)")
        }
    }

    /// Similar but different conditions must not tick each other.
    @Test func livelihoodAndPensionAreNotShared() {
        for plan in Plan.all {
            for step in plan.steps where ["livelihood", "income", "pension", "months"].contains(step.id) {
                #expect(step.shared == nil, "\(plan.id)/\(step.id)")
            }
        }
    }
}

@Suite struct FollowUpTests {
    struct Budget: ModelProvider {
        var displayName: String { "budget" }
        var contextBudget: Int { 7_000 }
        func plan(_ question: String) async throws -> QueryPlan { QueryPlan(route: .law) }
        func answer(_ request: AnswerRequest) async throws -> ModelAnswer { fatalError() }
    }

    /// "do I have to pass all of them?" on its own finds nothing useful; with the earlier turn's
    /// sections it must still reach § 10 StAG.
    @Test func followUpKeepsTheEarlierSections() {
        let engine = AnswerEngine(index: index, provider: Budget())
        let q = "do i have to pass all of them? or just some?"
        let earlier = index.referencedSections(in: "§ 10 StAG")
        let found = engine.retrieve(question: q, terms: QueryExpansion.questionWords(q), situation: Situation(), suggested: earlier)
        #expect(found.contains { $0.section.label == "§ 10 StAG" })
    }

    @Test func promptMentionsGoalNotesAndEarlierQuestions() {
        let c = ConversationContext(goal: "Einbürgerung (becoming German)", notes: "Studied in Germany 2018–2021",
                                    earlier: [.init(question: "What are the conditions for becoming German?", sections: ["§ 10 StAG"])])
        #expect(c.promptDescription.contains("Einbürgerung"))
        #expect(c.promptDescription.contains("2018"))
        #expect(c.promptDescription.contains("§ 10 StAG"))
    }
}

@Suite struct NearMatchTests {
    /// A quote with one word changed, from a paragraph the model was shown, is kept unhighlighted.
    @Test func nearMatchFromAGivenPassageIsKept() throws {
        let section = try #require(index.section(law: "StAG", number: "10"))
        let abs1 = try #require(section.paragraphs.first { $0.number == "1" })
        let c = Citation(law: "StAG", section: "10", paragraph: "1",
                         quote: "Ein Ausländer, der seit fünf Jahren rechtmäßig seinen gewöhnlichen Aufenthalt in Deutschland hat")
        let result = CitationChecker(index: index).check([c], given: [LawPassage(section: section, paragraph: abs1)])
        #expect(result.verified.first?.quoteMatched == false)
    }

    /// The same quote isn't kept if the model wasn't shown that paragraph.
    @Test func nearMatchWithoutTheGivenPassageIsRejected() {
        let c = Citation(law: "StAG", section: "10", paragraph: "1",
                         quote: "Ein Ausländer, der seit fünf Jahren rechtmäßig seinen gewöhnlichen Aufenthalt in Deutschland hat")
        #expect(CitationChecker(index: index).check([c]).verified.isEmpty)
    }
}

@Suite struct RepetitionLoopTests {
    /// Seen on 1 Oct 2026: qwen3.5:4b repeated § 36 StAG citations until it ran out of room.
    @Test func cutOffAnswerKeepsExplanationAndCompleteCitations() throws {
        let cut = #"{"explanation": "Five years and more.", "conditions": ["B1 German", "No convictions"], "citations": [{"law": "StAG", "section": "10", "quote": "seit fünf Jahren"}, {"law": "StAG", "section": "36", "quote": "(4) Für die Erh"#
        let repaired = try #require(JSONRepair.repair(Data(cut.utf8)))
        let answer = try JSONDecoder().decode(ModelAnswer.self, from: repaired)
        #expect(answer.explanation == "Five years and more.")
        #expect(answer.conditions.count == 2)
        #expect(answer.citations.map(\.section) == ["10"])
    }

    @Test func statisticsSectionNoLongerOutranksTheMainRule() {
        let hits = index.search(terms: ["Einbürgerung", "einzubürgern", "eingebürgert"], limit: 5)
        #expect(hits.first?.section.label != "§ 36 StAG")
    }
}

@Suite struct MainRuleTests {
    struct Budget: ModelProvider {
        var displayName: String { "budget" }
        var contextBudget: Int { 9_230 }
        func plan(_ question: String) async throws -> QueryPlan { QueryPlan(route: .law) }
        func answer(_ request: AnswerRequest) async throws -> ModelAnswer { fatalError() }
    }

    /// Seen on 1 Oct 2026: models said "the text doesn't list the requirements" because § 10 Abs. 1
    /// StAG was missing or cut off before B1 and the knowledge test.
    @Test func mainRuleArrivesFirstAndComplete() throws {
        let section = try #require(index.section(law: "StAG", number: "10"))
        let main = LawPassage(section: section, paragraph: section.paragraphs[0])
        let found = AnswerEngine(index: index, provider: Budget())
            .retrieve(question: "What are the conditions for becoming German?", terms: ["Einbürgerung"], situation: Situation(), required: [main])
        #expect(found.first?.label == "§ 10 Abs. 1 StAG")
        #expect(found.first?.paragraph.text.contains("Kenntnisse der Rechts- und Gesellschaftsordnung") == true)
    }
}

@Suite struct SmallModelOutputTests {
    @Test func cutInsideTheExplanationKeepsTheText() throws {
        let cut = #"{ "explanation": "The law says five years and B1 German, and"#
        let answer = try JSONDecoder().decode(ModelAnswer.self, from: try #require(JSONRepair.repair(Data(cut.utf8))))
        #expect(answer.explanation.hasPrefix("The law says five years"))
    }

    @Test func htmlIsStripped() {
        #expect(AnswerChecks.plainText("<p>Five years.</p> <h2 id=\"x\">Language</h2>B1") == "Five years.\n \nLanguage\nB1")
    }
}
