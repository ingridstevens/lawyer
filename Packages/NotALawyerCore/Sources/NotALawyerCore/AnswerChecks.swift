import Foundation

/// Checks on the model's explanation that the citation check can't make: it confirms quotes
/// exist, not that the explanation follows from them.
public enum AnswerChecks {
    /// Phrases that decide the user's case instead of explaining the law (spec §4). Lowercased,
    /// in the languages the evaluation covers. A hit doesn't block the answer; the app flags it.
    static let verdictPhrases = [
        // English
        "you qualify", "you don't qualify", "you do not qualify", "you are eligible", "you're eligible",
        "you are not eligible", "you can get", "you cannot get", "you can't get", "you will get", "you won't get",
        "you can apply", "you cannot apply", "you can't apply", "is not required", "you don't need", "you do not need",
        "you will lose", "you won't lose", "you will not lose",
        "applies to you", "applies to people like you", "in your case", "as your nationality", "this means you",
        // German
        "sie erfüllen", "sie haben anspruch", "sie bekommen", "sie können keine", "sie können eine", "nicht erforderlich",
        "sie verlieren", "du erfüllst", "du bekommst", "gilt für sie", "in ihrem fall",
        // Turkish
        "alabilirsiniz", "alamazsınız", "hak kazanırsınız", "gerekli değil", "gerekmez", "kaybedersiniz", "kaybetmezsiniz",
        "başvurabilirsiniz", "başvuramazsınız",
        // Spanish
        "usted puede obtener", "no puede obtener", "no es necesario", "cumple los requisitos",
        // Ukrainian / Russian
        "ви можете отримати", "ви не можете", "не потрібно", "вы можете получить", "вы не можете", "не требуется",
    ]

    /// Verdict-like phrases found in the explanation and conditions.
    public static func verdictPhrases(in answer: ModelAnswer) -> [String] {
        let text = ([answer.explanation] + answer.conditions).joined(separator: " ").lowercased()
        return verdictPhrases.filter { text.contains($0) }
    }

    /// Strips HTML tags some small models write into the explanation.
    public static func plainText(_ s: String) -> String {
        s.replacing(/<\/?(p|h[1-6]|br|ul|ol|li|strong|em|b|i|span|div)[^>]*>/, with: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes checklist items that are empty, duplicated or leaked from the model's JSON.
    public static func cleanConditions(_ conditions: [String]) -> [String] {
        var seen = Set<String>()
        return conditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { item in
                !item.isEmpty && item.count < 400
                    && !item.contains("{") && !item.contains("citations") && !item.contains("':")
                    && seen.insert(item.lowercased()).inserted
            }
    }
}
