import Foundation

/// What the app shows for one question (spec §6, step 4–5).
public struct Answer: Sendable, Codable {
    public var question: String
    /// Non-law questions get no search and no explanation; the app answers them itself.
    public var route: QuestionRoute = .law
    /// Hand-written background shown with the answer, if the question matched a topic note.
    public var topicNotes: [TopicNote] = []
    /// Phrases in the explanation that sound like a decision about the user's case.
    public var verdictPhrases: [String] = []
    /// Seconds per stage ("plan", "search", "answer", "check"), to find what's slow.
    public var timings: [String: Double] = [:]
    /// Characters of law text given to the model.
    public var promptCharacters = 0
    /// Empty for a refusal.
    public var explanation: String
    public var conditions: [String]
    /// Only citations that passed the verbatim check.
    public var citations: [VerifiedCitation]
    public var refused: Bool
    /// For a refusal: the closest sections found, if any.
    public var closest: [LawPassage]

    // Kept for the evaluation and for debugging.
    public var plan: QueryPlan?
    public var searchTerms: [String]
    public var retrieved: [LawPassage]
    public var rejected: [CitationRejection]
    /// What the model returned, before the checks.
    public var raw: ModelAnswer?
}

/// Where an answer is, for the progress shown while the user waits.
public enum AnswerStage: Sendable, Equatable {
    /// Waiting for the model to finish another question (the app sets this, not the engine).
    case queued
    case searching
    /// Section labels handed to the model, e.g. ["§ 9 AufenthG", "§ 9a AufenthG"].
    case writing(sections: [String])
    case checking
}

/// Retrieve → generate from retrieved passages only → check citations → answer or refuse.
public struct AnswerEngine: Sendable {
    public let index: LawIndex
    public let provider: any ModelProvider
    /// Whether to ask the model to route the question and suggest search terms and sections
    /// first. Costs one short model call.
    public var planQuery = true

    public init(index: LawIndex, provider: any ModelProvider) {
        self.index = index
        self.provider = provider
    }

    public func ask(_ question: String, preferences: AnswerPreferences, situation: Situation = Situation(),
                    memory: [String] = [], conversation: ConversationContext = ConversationContext(), onStage: @Sendable (AnswerStage) -> Void = { _ in }) async throws -> Answer {
        // 1. Retrieve.
        onStage(.searching)
        // A follow-up ("do I have to pass all of them?") is searched together with the chat's goal
        // and the previous question, so it keeps its topic.
        var timings: [String: Double] = [:]
        var clock = Date()
        func lap(_ name: String) { timings[name] = Date().timeIntervalSince(clock); clock = Date() }
        let contextText = ([conversation.goal ?? ""] + conversation.earlier.suffix(1).map(\.question)).joined(separator: " ")
        let dictionaryTerms = QueryExpansion.terms(for: question) + QueryExpansion.terms(for: contextText)
        let topics = TopicNote.matching(question)
        var plan = QueryPlan(route: .law)
        let planInput = conversation.earlier.isEmpty && conversation.goal == nil ? question
            : "Context: \(contextText)\nQuestion: \(question)"
        // The planning call costs a model round trip. Skip it when the dictionary already
        // recognises a law question; the dictionary's terms are enough to search.
        let recognised = !QueryExpansion.terms(for: question).isEmpty || question.contains("§")
        if planQuery && !recognised, let planned = try? await provider.plan(planInput) { plan = planned }
        lap("plan")
        // The dictionary and § references are certain signs of a law question; trust them over the model.
        if plan.route != .law, !QueryExpansion.terms(for: question).isEmpty || !topics.isEmpty || question.contains("§") { plan.route = .law }
        guard plan.route == .law else {
            return Answer(question: question, route: plan.route, explanation: "", conditions: [], citations: [],
                          refused: false, closest: [], plan: plan, searchTerms: [], retrieved: [], rejected: [], raw: nil)
        }

        let terms = dictionaryTerms + situation.searchTerms + QueryExpansion.questionWords(question)
            + QueryExpansion.cleanPlannedTerms(plan.terms)
        // Sections cited earlier in the chat are likely relevant to a follow-up.
        let earlierSections = conversation.earlier.suffix(2).flatMap(\.sections)
        // Suggestions must name their law: a bare "§ 10" would pull in § 10 of every law.
        let anchors = QueryExpansion.anchorSections(for: dictionaryTerms)
        let suggested = index.referencedSections(in: (anchors + plan.sections + earlierSections).joined(separator: " "), requireLaw: true)
        let topicPassages = passages(for: topics)
        // A lawyer reads the main rule first, in full: the first paragraph of each anchor section
        // (§ 10 Abs. 1 StAG lists the conditions for naturalisation) always goes in, at the top.
        let mainRules = index.referencedSections(in: anchors.joined(separator: " "), requireLaw: true)
            .compactMap { s in s.paragraphs.first.map { LawPassage(section: s, paragraph: $0) } }
        let passages = retrieve(question: question, terms: terms, situation: situation, suggested: suggested,
                                required: mainRules + topicPassages)
        lap("search")
        guard !passages.isEmpty else {
            var answer = refusal(question, plan: plan, terms: terms, retrieved: [], raw: nil, rejected: [])
            answer.timings = timings
            return answer
        }

        // 2. Generate from the retrieved passages only.
        var labels: [String] = []
        for p in passages where !labels.contains(p.section.label) { labels.append(p.section.label) }
        onStage(.writing(sections: labels))
        var request = AnswerRequest(question: question, passages: passages, preferences: preferences, situation: situation,
                                    memory: memory)
        request.conversation = conversation
        request.topicNotes = topics.map(\.note)
        var raw = try await provider.answer(request)
        lap("answer")
        raw.conditions = AnswerChecks.cleanConditions(raw.conditions).map(AnswerChecks.plainText)
        raw.explanation = AnswerChecks.plainText(raw.explanation)

        // 3. Check every citation.
        onStage(.checking)
        var (verified, rejected) = CitationChecker(index: index).check(raw.citations, given: passages)
        // Small models often garble nested quotes but name their sources correctly. If no quote
        // survived, show the passages they named (only ones they were given), unhighlighted.
        if verified.isEmpty && !raw.refused {
            let named = Set(raw.sources.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")) })
            verified = passages.filter { named.contains($0.label) }.prefix(4).map { p in
                let full = index.section(law: p.section.law, number: p.section.number)?
                    .paragraphs.first { $0.number == p.paragraph.number } ?? p.paragraph
                var v = VerifiedCitation(passage: LawPassage(section: p.section, paragraph: full), quote: "", translation: nil, about: nil)
                v.quoteMatched = false
                return v
            }
        }
        lap("check")
        let promptCharacters = passages.map(\.paragraph.text.count).reduce(0, +)
        if raw.refused || verified.isEmpty {
            var answer = refusal(question, plan: plan, terms: terms, retrieved: passages, raw: raw, rejected: rejected)
            answer.topicNotes = topics
            answer.timings = timings
            answer.promptCharacters = promptCharacters
            return answer
        }
        var answer = Answer(question: question, explanation: raw.explanation, conditions: raw.conditions,
                      citations: verified, refused: false, closest: [], plan: plan, searchTerms: terms,
                      retrieved: passages, rejected: rejected, raw: raw)
        answer.topicNotes = topics
        answer.verdictPhrases = AnswerChecks.verdictPhrases(in: raw)
        answer.timings = timings
        answer.promptCharacters = promptCharacters
        return answer
    }

    /// Sections named in the question come first, then keyword hits, within the model's budget.
    ///
    /// Hits are ranked by section, not by paragraph: the paragraph that lists a rule's
    /// conditions is often long and scores lower than a short one that merely names the
    /// permit, but the model needs both. A section scores the sum of 1/(rank + 5) over its
    /// hits, and its hit paragraphs are then given in their order in the law.
    /// The paragraphs a topic note points to, always given to the model when the note applies.
    public func passages(for topics: [TopicNote]) -> [LawPassage] {
        topics.flatMap(\.sections).compactMap { ref -> LawPassage? in
            guard let s = index.section(law: ref.law, number: ref.section),
                  let p = s.paragraphs.first(where: { $0.number == ref.paragraph }) ?? s.paragraphs.first else { return nil }
            return LawPassage(section: s, paragraph: p)
        }
    }

    /// Sections the planning step suggested get a bonus worth about one strong hit, so a correct
    /// suggestion lifts its section while an invented one can't crowd out what search found.
    public func retrieve(question: String, terms: [String], situation: Situation, suggested: [LawSection] = [],
                         required: [LawPassage] = []) -> [LawPassage] {
        let referenced = required + index.referencedSections(in: question).flatMap { s in
            s.paragraphs.map { LawPassage(section: s, paragraph: $0) }
        }
        let boost = situation.lawBoost.merging(QueryExpansion.lawBoost(for: question), uniquingKeysWith: *)
        let paragraphHits = index.search(terms: terms, lawBoost: boost, limit: 60)
        var sectionScore: [String: Double] = [:]
        var sectionHits: [String: [LawPassage]] = [:]
        for (rank, p) in paragraphHits.enumerated() {
            sectionScore[p.section.label, default: 0] += 1 / Double(rank + 5)
            sectionHits[p.section.label, default: []].append(p)
        }
        // Repealed sections ("weggefallen") have no paragraphs; there's nothing to read in them.
        for section in suggested where !section.paragraphs.isEmpty {
            sectionScore[section.label, default: 0] += 0.15
            if sectionHits[section.label] == nil {
                sectionHits[section.label] = section.paragraphs.prefix(3).map { LawPassage(section: section, paragraph: $0) }
            }
        }
        // At most the three best-matching paragraphs per section, in the law's order, so one
        // long section (§ 18g has seven paragraphs) can't fill the budget and push out the next
        // one (§ 18c, where the Blue Card's route to permanent residence is).
        let hits = sectionScore.sorted { $0.value > $1.value }.flatMap { label, _ -> [LawPassage] in
            guard let found = sectionHits[label], let section = found.first?.section else { return [] }
            let best = found.prefix(3)
            return section.paragraphs.filter { para in best.contains { $0.paragraph == para } }
                .map { LawPassage(section: section, paragraph: $0) }
        }

        // Fill the budget in rank order. A paragraph longer than a third of the budget is cut at a
        // word boundary, so one long paragraph can't crowd out everything else; the cut text is
        // still verbatim, and citations are checked against the full paragraph anyway.
        let cap = max(provider.contextBudget / 3, 1_200)
        // Required passages (main rules, topic notes) get more room, so a long list of conditions
        // isn't cut off before its last items.
        let requiredCap = max(provider.contextBudget * 6 / 10, 1_200)
        let requiredLabels = Set(required.map(\.label))
        var chosen: [LawPassage] = []
        var used = 0
        for var passage in referenced + hits where !chosen.contains(where: { $0.label == passage.label }) {
            passage.paragraph.text = Self.truncate(passage.paragraph.text, to: requiredLabels.contains(passage.label) ? requiredCap : cap)
            let size = passage.paragraph.text.count + passage.section.heading.count + 30
            guard used + size <= provider.contextBudget else { continue }
            chosen.append(passage)
            used += size
        }
        return chosen
    }

    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        let cut = text[..<end].lastIndex(of: " ") ?? end
        return text[..<cut] + " …"
    }

    private func refusal(_ question: String, plan: QueryPlan, terms: [String], retrieved: [LawPassage], raw: ModelAnswer?,
                         rejected: [CitationRejection]) -> Answer {
        var seen = Set<String>()
        let closest = retrieved.filter { seen.insert($0.section.label).inserted }.prefix(3)
        return Answer(question: question, explanation: "", conditions: [], citations: [], refused: true,
                      closest: Array(closest), plan: plan, searchTerms: terms, retrieved: retrieved, rejected: rejected, raw: raw)
    }
}
