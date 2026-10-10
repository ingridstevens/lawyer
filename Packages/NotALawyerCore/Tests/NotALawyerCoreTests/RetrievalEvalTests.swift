import Foundation
import Testing
@testable import NotALawyerCore

/// Retrieval quality on eval/questions.jsonl, without a model, so it runs in every `swift test`.
///
/// Uses only what doesn't need a model: the dictionary, words from the question and section
/// references. The planning step (model-suggested terms) can only add to this. If a change to
/// search drops recall below the floor, this fails; raise the floor when search improves.
@Suite struct RetrievalEvalTests {
    struct Question: Decodable {
        let id: String
        let question: String
        let gold: [String]
        let shouldRefuse: Bool
    }

    /// A provider that's never called; it only sets the context budget.
    struct Budget: ModelProvider {
        let contextBudget: Int
        var displayName: String { "budget \(contextBudget)" }
        func plan(_ question: String) async throws -> QueryPlan { QueryPlan(route: .law) }
        func answer(_ request: AnswerRequest) async throws -> ModelAnswer { fatalError() }
    }

    static let questions: [Question] = {
        let url = snapshotDirectory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("eval/questions.jsonl")
        return try! String(contentsOf: url, encoding: .utf8).split(separator: "\n")
            .map { try! JSONDecoder().decode(Question.self, from: Data($0.utf8)) }
            .filter { !$0.shouldRefuse && !$0.gold.isEmpty }
    }()

    static func recall(budget: Int) -> (hits: Int, misses: [String]) {
        let engine = AnswerEngine(index: index, provider: Budget(contextBudget: budget))
        var hits = 0
        var misses: [String] = []
        for q in questions {
            let terms = QueryExpansion.terms(for: q.question) + QueryExpansion.questionWords(q.question)
            let required = engine.passages(for: TopicNote.matching(q.question))
            let anchors = index.referencedSections(in: QueryExpansion.anchorSections(for: QueryExpansion.terms(for: q.question)).joined(separator: " "), requireLaw: true)
            let found = Set(engine.retrieve(question: q.question, terms: terms, situation: Situation(), suggested: anchors, required: required).map(\.section.label))
            if q.gold.contains(where: found.contains) { hits += 1 } else { misses.append(q.id) }
        }
        return (hits, misses)
    }

    // Floors: 42/45 at 5,000 characters (Apple) and 44/45 at ~9,200 (local), measured 2026-10-01.
    // Re-based that day because the budgets were cut on purpose, from 7,000 and 15,000, to leave
    // the model room to answer. Raise them when search improves; never lower them to make a change pass.
    @Test func recallWithinAppleBudget() {
        let (hits, misses) = Self.recall(budget: 5_000)
        print("Retrieval recall, Apple budget: \(hits)/\(Self.questions.count). Missed: \(misses.joined(separator: ", "))")
        #expect(Double(hits) / Double(Self.questions.count) >= RetrievalEvalTests.appleFloor)
    }

    @Test func recallWithinLocalServerBudget() {
        let (hits, misses) = Self.recall(budget: 9_230)
        print("Retrieval recall, local-server budget: \(hits)/\(Self.questions.count). Missed: \(misses.joined(separator: ", "))")
        #expect(Double(hits) / Double(Self.questions.count) >= RetrievalEvalTests.localFloor)
    }

    static let appleFloor = 0.93
    static let localFloor = 0.97
}
