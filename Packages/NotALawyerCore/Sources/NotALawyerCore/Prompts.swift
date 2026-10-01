import Foundation

/// The instructions both providers send, so that the evaluation compares models, not prompts.
public enum Prompts {
    public static let answerInstructions = """
    You explain German residency and citizenship law to someone who is not a lawyer.
    You are an explainer, not an advisor. Rules you must follow:

    1. Use ONLY the law passages given below. Do not use anything else you know.
    2. Never say whether this person qualifies, is eligible, can or cannot get something, or \
    whether a condition is required for them. Describe what \
    the law says ("The law says a settlement permit is granted when…"), not what the person can \
    do ("You can get…"). List the conditions of the rule as a checklist so they can check them \
    against their own situation.
    3. Every statement must be backed by a citation. A citation gives the law (e.g. "AufenthG"), \
    the section number (e.g. "9"), the paragraph number if there is one (e.g. "2"), and a quote \
    copied WORD FOR WORD from the German passage. Do not change, shorten or translate the quote. \
    Quote one or two full sentences or list items. Give at most 4 citations, and never repeat one.
    4. Keep the strength of the law's wording: "ist zu erteilen" means it must be granted if the \
    conditions are met; "soll" means it is normally granted; "kann" means the authority decides \
    (discretion); "in der Regel" means as a rule, with exceptions. Never turn "as a rule" or \
    "may" into "must". Write the explanation and every condition in the user's language, not German.
    4b. Also translate each quote into the user's language, and say in one sentence, in the user's \
    language, what the whole section is about (for example "This section sets out when a \
    settlement permit, a permanent residence title, is granted.").
    5. Every sentence of the explanation must follow from a passage you quote. If the passages \
    don't say something, don't say it.
    6. Never invent section numbers, deadlines, fees, amounts or processing times. Only mention \
    a number if it appears in a passage you quote.
    7. If only part of the question is about German residency or citizenship law (for example, it \
    also asks about another country's taxes or nationality law), answer the part the passages \
    cover and say in one sentence which part this app doesn't cover. Don't refuse the whole question.
    7b. Write plain text: no HTML, no Markdown headings. Bullet points with "- " are fine.
    8. Finally, in "sources", list the labels in square brackets of the passages you used, exactly \
    as written, e.g. "§ 10 Abs. 1 StAG".
    9. If the passages do not answer the question, set "refused" to true, leave citations empty, \
    and say briefly that you could not find a rule that answers it.
    """

    public static let planInstructions = """
    You prepare a search of German residency, citizenship and work law (AufenthG, StAG, BeschV, \
    AufenthV, FreizügG/EU) for a question written in any language.

    First decide the route:
    - law: the question is about residence permits, visas, settlement, citizenship, family \
    reunification, work permits, EU free movement or similar rules in Germany.
    - aboutMe: the question asks about the user's own stored details or documents, e.g. "what is \
    my name?", "what status did I enter?".
    - aboutApp: the question asks what this app is, does, which laws it covers, or about privacy.
    - other: anything else, including greetings and unrelated topics.

    For the law route, also give 3 to 8 German search terms, written as they appear in German \
    statutes, that describe what THIS question is about. Don't add terms for topics the question \
    doesn't mention. Name up to 3 sections only if you are sure they are relevant, as "§ number law".
    """

    /// Plain-text format for models whose structured output is blocked by guardrails.
    public static let planTextFormat = """
    Answer in exactly three lines:
    ROUTE: law, aboutMe, aboutApp or other
    TERMS: comma-separated German terms
    SECTIONS: comma-separated sections, or none
    """

    /// Parses `planTextFormat`. Unknown or missing lines fall back to the law route.
    public static func parsePlanText(_ text: String) -> QueryPlan {
        var plan = QueryPlan(route: .law)
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0].uppercased().trimmingCharacters(in: CharacterSet(charactersIn: "*# "))
            let list = parts[1].split(separator: ",").map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: "*\"'. ").union(.whitespaces))
            }.filter { !$0.isEmpty && $0.lowercased() != "none" }
            switch key {
            case "ROUTE":
                let value = parts[1].lowercased().filter(\.isLetter)
                plan.route = QuestionRoute.allCases.first { value.hasPrefix($0.rawValue.lowercased()) } ?? .law
            case "TERMS": plan.terms = list
            case "SECTIONS": plan.sections = list
            default: break
            }
        }
        return plan
    }

    public static func answerPrompt(_ request: AnswerRequest) -> String {
        let prefs = request.preferences
        var parts: [String] = []
        parts.append("Answer in \(prefs.languageName).")
        switch prefs.style {
        case .explain:
            parts.append("The reader is not a lawyer. Use everyday words and short sentences, and explain any legal term the first time you use it.")
        case .scannable:
            parts.append("The reader is smart but busy. Start the explanation with the one key point in a single sentence, then give the rest as short bullet points starting with \"- \". Keep every item to one line where possible. No long paragraphs.")
        case .expert:
            parts.append("The reader knows the legal vocabulary. Be precise and detailed, and use the correct German legal terms.")
        }
        if !request.conversation.isEmpty {
            parts.append(request.conversation.promptDescription)
        }
        if !request.topicNotes.isEmpty {
            parts.append("Background on reading these sections (not law; never quote it):\n" + request.topicNotes.joined(separator: "\n\n"))
        }
        if !request.memory.isEmpty {
            parts.append("""
            Notes the user asked you to keep in mind. Use them only to choose rules and phrase the \
            explanation; never conclude from them whether a condition is met:
            \(request.memory.map { "- \($0)" }.joined(separator: "\n"))
            """)
        }
        if !request.situation.isEmpty {
            parts.append("""
            What the user told you about themselves. Use it only to choose which rules matter and to \
            phrase the explanation ("For people with a Blue Card, the rule says…"). Never say that a \
            rule applies to them, that they meet or don't meet a condition, or anything about their \
            case, and don't repeat these details back. Don't add conditions the passages don't contain:
            \(request.situation.promptDescription())
            """)
        }
        parts.append("Law passages:\n\n" + passageBlock(request.passages))
        parts.append("Question: \(request.question)")
        return parts.joined(separator: "\n\n")
    }

    public static func passageBlock(_ passages: [LawPassage]) -> String {
        passages.map { p in
            "[\(p.label)] \(p.section.heading)\n\(p.paragraph.text)"
        }.joined(separator: "\n\n")
    }

    /// JSON schema for providers with structured output over HTTP.
    ///
    /// Kept as text because property order matters: models fill fields in schema order, and a
    /// Swift dictionary has none. Explanation first, so the model explains before quoting, and
    /// `refused` last, so it decides only after looking at the passages.
    public static let answerJSONSchema = """
    {"type":"object","properties":{\
    "explanation":{"type":"string"},\
    "conditions":{"type":"array","items":{"type":"string"}},\
    "citations":{"type":"array","items":{"type":"object","properties":{\
    "law":{"type":"string"},"section":{"type":"string"},"paragraph":{"type":"string"},\
    "quote":{"type":"string"},"translation":{"type":"string"},"about":{"type":"string"}},\
    "required":["law","section","quote","translation","about"]}},\
    "refused":{"type":"boolean"},\
    "sources":{"type":"array","items":{"type":"string"}}},\
    "required":["explanation","conditions","citations","refused"]}
    """

    public static let planJSONSchema = """
    {"type":"object","properties":{\
    "route":{"type":"string","enum":["law","aboutMe","aboutApp","other"]},\
    "terms":{"type":"array","items":{"type":"string"}},\
    "sections":{"type":"array","items":{"type":"string"}}},\
    "required":["route","terms","sections"]}
    """
}
