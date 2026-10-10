import Foundation

/// A citation the model claims supports its answer. Checked verbatim before display (spec §6).
public struct Citation: Sendable, Hashable, Codable {
    /// e.g. "AufenthG".
    public var law: String
    /// e.g. "9" or "18a".
    public var section: String
    /// Paragraph (Abs.), e.g. "2" or "3a", if the model gave one.
    public var paragraph: String?
    /// Text the model says it quotes word for word from the German original.
    public var quote: String
    /// The model's translation of the quote into the user's language.
    public var translation: String?
    /// One sentence, in the user's language, on what the whole section is about.
    public var about: String?

    public init(law: String, section: String, paragraph: String? = nil, quote: String, translation: String? = nil,
                about: String? = nil) {
        self.law = law
        self.section = section
        self.paragraph = paragraph
        self.quote = quote
        self.translation = translation
        self.about = about
    }

    public init(from decoder: any Decoder) throws {
        // Lenient: small models drop optional fields or write numbers as numbers.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ key: CodingKeys) -> String? {
            if let s = try? c.decode(String.self, forKey: key) { return s }
            if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
            return nil
        }
        law = string(.law) ?? ""
        section = string(.section) ?? ""
        paragraph = string(.paragraph).flatMap { $0.isEmpty ? nil : $0 }
        quote = string(.quote) ?? ""
        translation = string(.translation)
        about = string(.about)
    }
}

/// What the model returns, before any checks.
public struct ModelAnswer: Sendable, Codable {
    public var explanation: String
    /// Conditions of the rule, as a checklist the user checks themselves. Never a verdict.
    public var conditions: [String]
    public var citations: [Citation]
    /// True when no retrieved paragraph answers the question.
    public var refused: Bool
    /// Labels of the passages the answer is based on, as shown to the model ("§ 10 Abs. 1 StAG").
    /// Easy even for small models; used when their word-for-word quotes fail.
    public var sources: [String] = []

    public init(explanation: String, conditions: [String], citations: [Citation], refused: Bool, sources: [String] = []) {
        self.explanation = explanation
        self.conditions = conditions
        self.citations = citations
        self.refused = refused
        self.sources = sources
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        explanation = (try? c.decode(String.self, forKey: .explanation)) ?? ""
        conditions = (try? c.decode([String].self, forKey: .conditions)) ?? []
        citations = (try? c.decode([Citation].self, forKey: .citations)) ?? []
        refused = (try? c.decode(Bool.self, forKey: .refused)) ?? false
        sources = (try? c.decode([String].self, forKey: .sources)) ?? []
    }
}

/// What the chat already established: its goal, the user's notes for it, and earlier turns.
/// Lets follow-ups like "do I have to pass all of them?" keep their topic.
public struct ConversationContext: Sendable {
    /// e.g. "Einbürgerung (becoming German)".
    public var goal: String?
    /// The user's own notes for this chat.
    public var notes: String
    public var earlier: [EarlierTurn]

    public struct EarlierTurn: Sendable {
        public var question: String
        /// Labels of the sections cited in its answer, e.g. "§ 10 StAG".
        public var sections: [String]
        public init(question: String, sections: [String]) { self.question = question; self.sections = sections }
    }

    public init(goal: String? = nil, notes: String = "", earlier: [EarlierTurn] = []) {
        self.goal = goal
        self.notes = notes
        self.earlier = earlier
    }

    public var isEmpty: Bool { goal == nil && notes.isEmpty && earlier.isEmpty }

    /// For the prompt.
    public var promptDescription: String {
        var lines: [String] = []
        if let goal { lines.append("The user's goal in this chat: \(goal). Answer with that goal in mind.") }
        if !notes.isEmpty { lines.append("The user's notes for this chat: \(notes)") }
        if !earlier.isEmpty {
            lines.append("Earlier in this chat (use this to understand follow-up questions like \"them\" or \"that\"):")
            for turn in earlier {
                lines.append("- Asked: \(turn.question)" + (turn.sections.isEmpty ? "" : " (answered from \(turn.sections.joined(separator: ", ")))"))
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// Everything the model needs for one answer: the prompts are built by `Prompts`,
/// so both providers see the same instructions.
public struct AnswerRequest: Sendable {
    public var question: String
    public var passages: [LawPassage]
    public var preferences: AnswerPreferences
    public var situation: Situation
    /// Notes the user asked the app to remember.
    public var memory: [String]
    /// Background from `TopicNotes` for this question.
    public var topicNotes: [String] = []
    public var conversation = ConversationContext()

    public init(question: String, passages: [LawPassage], preferences: AnswerPreferences, situation: Situation,
                memory: [String] = []) {
        self.question = question
        self.passages = passages
        self.preferences = preferences
        self.situation = situation
        self.memory = memory
    }
}

/// What kind of question this is. Only law questions are searched and answered from the law.
public enum QuestionRoute: String, Sendable, Codable, CaseIterable {
    /// About German residency, citizenship or work law: search the law and quote it.
    case law
    /// About the user's own stored details or documents ("what's my status?").
    case aboutMe
    /// About this app: what it does, which laws, privacy.
    case aboutApp
    /// Anything else: greetings, other topics.
    case other
}

/// The planning step before retrieval: route the question and suggest where to look.
public struct QueryPlan: Sendable, Codable {
    public var route: QuestionRoute
    /// German legal search terms.
    public var terms: [String]
    /// Sections the model expects to be relevant, e.g. ["§ 9 AufenthG"]. Read directly, like a tool call.
    public var sections: [String]

    public init(route: QuestionRoute, terms: [String] = [], sections: [String] = []) {
        self.route = route
        self.terms = terms
        self.sections = sections
    }
}

/// The single interface both model routes implement (spec §7).
public protocol ModelProvider: Sendable {
    /// Shown in Settings and in evaluation reports, e.g. "Ollama · qwen2.5:14b".
    var displayName: String { get }

    /// Roughly how many characters of law text fit in the model's context.
    var contextBudget: Int { get }

    /// Routes the question and rewrites it into German legal search terms (spec §9).
    func plan(_ question: String) async throws -> QueryPlan

    /// Answers using only `request.passages`.
    func answer(_ request: AnswerRequest) async throws -> ModelAnswer
}
