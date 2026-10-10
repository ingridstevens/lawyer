import Foundation
import FoundationModels
import NotALawyerCore

/// Apple's on-device model via the Foundation Models framework (spec §7).
///
/// The model has a small context window (4,096 tokens for prompt and answer together),
/// so it gets fewer passages than a local server, and halves them again if they still
/// don't fit.
public struct FoundationModelsProvider: ModelProvider {
    public var displayName: String { "Apple on-device model" }
    /// Apple's model has 4,096 tokens for everything; ~5,000 characters of law leaves room to answer.
    public var contextBudget: Int { 5_000 }

    public init() {}

    /// Whether Apple Intelligence is enabled and the model is ready on this Mac.
    public static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Why the model can't be used, in words for Settings; nil when it's ready.
    public static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: nil
        case .unavailable(.deviceNotEligible): "This Mac doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): "Apple Intelligence is turned off in System Settings."
        case .unavailable(.modelNotReady): "Apple's model is still downloading. Try again later."
        case .unavailable: "Apple's model isn't available."
        }
    }

    /// Whether the on-device model supports answering in the language with this BCP 47 code.
    public static func supportsLanguage(_ code: String) -> Bool {
        SystemLanguageModel.default.supportsLocale(Locale(identifier: code))
    }

    // MARK: ModelProvider

    /// The default guardrails flag ordinary residency questions as unsafe. Planning a search is a
    /// content transformation, which the permissive mode is meant for; it only applies to plain-text
    /// output, so the plan comes back as three labelled lines.
    public func plan(_ question: String) async throws -> QueryPlan {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: Prompts.planInstructions + "\n\n" + Prompts.planTextFormat)
        // Capped, because greedy sampling sometimes repeats terms until the context is full.
        let response = try await session.respond(to: question, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 150))
        return Prompts.parsePlanText(response.content)
    }

    public func answer(_ request: AnswerRequest) async throws -> ModelAnswer {
        var request = request
        // The default guardrails, and the model itself, sometimes block ordinary questions about
        // leaving a country or losing a permit. Explaining given legal text is a content
        // transformation, so a blocked answer is retried in the permissive mode, which only works
        // for plain text: the JSON then comes back as text.
        var asText = false
        while true {
            do {
                if asText { return try await answerAsText(request) }
                let session = LanguageModelSession(instructions: Prompts.answerInstructions)
                let response = try await session.respond(to: Prompts.answerPrompt(request), generating: GeneratedAnswer.self,
                                                         options: GenerationOptions(sampling: .greedy))
                return response.content.modelAnswer
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize where request.passages.count > 1 {
                request.passages = Array(request.passages.prefix(request.passages.count / 2))
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation, .refusal:
                    guard !asText else { throw FoundationModelsError.blocked }
                    asText = true
                default:
                    throw error
                }
            }
        }
    }

    func answerAsText(_ request: AnswerRequest) async throws -> ModelAnswer {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: Prompts.answerInstructions + """

        Reply with only a JSON object in this shape, with no other text:
        \(Prompts.answerJSONSchema)
        """)
        let response = try await session.respond(to: Prompts.answerPrompt(request),
                                                 options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 1_200))
        let text = response.content
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
              let answer = try? JSONDecoder().decode(ModelAnswer.self, from: Data(text[start...end].utf8)) else {
            if ProcessInfo.processInfo.environment["NAL_DEBUG"] != nil {
                FileHandle.standardError.write(Data("Unreadable answer from Apple's model:\n\(text)\n".utf8))
            }
            throw FoundationModelsError.unreadableAnswer
        }
        return answer
    }
}

// MARK: Guided generation types

@Generable
struct GeneratedCitation {
    @Guide(description: "Short name of the law, exactly as in the passage label, e.g. AufenthG or StAG")
    var law: String
    @Guide(description: "Section number without §, e.g. 9 or 18a")
    var section: String
    @Guide(description: "Paragraph (Abs.) number, e.g. 2, or empty if the passage has none")
    var paragraph: String
    @Guide(description: "One or two sentences copied word for word from the German passage")
    var quote: String
    @Guide(description: "Translation of the quote into the user's language")
    var translation: String
    @Guide(description: "One sentence in the user's language on what the whole section is about")
    var about: String
}

@Generable
struct GeneratedAnswer {
    @Guide(description: "Short explanation in the user's language. Never says whether the user qualifies.")
    var explanation: String
    @Guide(description: "The conditions of the rule, one per item, in the user's language")
    var conditions: [String]
    @Guide(description: "Labels in square brackets of the passages the explanation is based on, e.g. § 10 Abs. 1 StAG")
    var sources: [String]
    @Guide(description: "Citations backing the explanation; empty if refused")
    var citations: [GeneratedCitation]
    // Last on purpose: guided generation fills properties in order, and asking first made
    // the model refuse before it had looked at the passages.
    @Guide(description: "True only if no passage answers the question and citations is empty")
    var refused: Bool

    var modelAnswer: ModelAnswer {
        ModelAnswer(
            explanation: explanation, conditions: conditions,
            citations: citations.map {
                Citation(law: $0.law, section: $0.section, paragraph: $0.paragraph.isEmpty ? nil : $0.paragraph,
                         quote: $0.quote, translation: $0.translation, about: $0.about)
            },
            refused: refused,
            sources: sources
        )
    }
}

enum FoundationModelsError: Error, LocalizedError {
    case unreadableAnswer
    case blocked

    var errorDescription: String? {
        switch self {
        case .unreadableAnswer:
            "Apple's model couldn't put its answer in the expected format. Try rephrasing, or choose a local model in Settings → Model."
        case .blocked:
            "Apple's model declined to answer this. Its built-in safety filter sometimes blocks ordinary questions about permits or leaving a country. Try a local model in Settings → Model, or rephrase the question."
        }
    }
}
