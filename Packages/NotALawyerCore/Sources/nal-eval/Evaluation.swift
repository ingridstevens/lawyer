import Foundation
import NaturalLanguage
import NotALawyerCore

/// One line of eval/questions.jsonl.
struct EvalQuestion: Codable {
    var id: String
    /// BCP 47 code the question is written in and should be answered in.
    var lang: String
    var question: String
    /// Correct sections, e.g. ["§ 9 AufenthG"]. Empty when the right behaviour is to refuse.
    var gold: [String]
    var reference: String
    var shouldRefuse: Bool
    /// Expected route for non-law questions: "aboutMe", "aboutApp" or "other".
    var route: String?
}

/// The automatic measures from spec §10. Answer correctness is graded by hand from the report.
struct EvalResult: Codable {
    var id: String
    var lang: String
    var question: String
    var gold: [String]
    var shouldRefuse: Bool
    var refused: Bool
    var cited: [String]
    var retrieved: [String]
    var explanation: String
    var conditions: [String]
    var reference: String
    var error: String?
    var seconds: Double
    var expectedRoute: String?
    var actualRoute: String = "law"

    /// Retrieval found at least one gold section (diagnostic: the model can't cite what it never saw).
    var retrievalHit: Bool { gold.isEmpty || gold.contains { retrieved.contains($0) } }
    /// At least one surviving citation is a gold section.
    var citationHit: Bool { !gold.isEmpty && gold.contains { cited.contains($0) } }
    /// A non-law route counts as declining to answer from the law.
    var refusalCorrect: Bool { (refused || actualRoute != "law") == shouldRefuse }
    var routeCorrect: Bool { actualRoute == (expectedRoute ?? "law") || (expectedRoute == nil && shouldRefuse) }
    var detectedLanguage: String?
    var languageCorrect: Bool { refused || detectedLanguage == lang }
    /// Citations the checker removed: invented sections or quotes not found verbatim.
    var rejectedCitations: Int
    /// Numbers in the explanation or checklist that appear in none of the cited passages or the question.
    var unsupportedNumbers: [String]
}

enum Evaluation {
    static func run(engine: AnswerEngine, questions: URL, out: URL) async throws {
        let lines = try String(contentsOf: questions, encoding: .utf8).split(separator: "\n").filter { !$0.isEmpty }
        let qs = try lines.map { try JSONDecoder().decode(EvalQuestion.self, from: Data($0.utf8)) }
        var results: [EvalResult] = []

        for (i, q) in qs.enumerated() {
            print("[\(i + 1)/\(qs.count)] \(q.id) \(q.question.prefix(70))")
            let started = Date()
            var r = EvalResult(id: q.id, lang: q.lang, question: q.question, gold: q.gold, shouldRefuse: q.shouldRefuse,
                               refused: true, cited: [], retrieved: [], explanation: "", conditions: [],
                               reference: q.reference, seconds: 0, expectedRoute: q.route, rejectedCitations: 0,
                               unsupportedNumbers: [])
            do {
                let a = try await engine.ask(q.question, preferences: AnswerPreferences(languageCode: q.lang))
                r.refused = a.refused
                r.actualRoute = a.route.rawValue
                r.cited = Array(Set(a.citations.map(\.passage.section.label))).sorted()
                r.retrieved = Array(Set(a.retrieved.map(\.section.label))).sorted()
                r.explanation = a.explanation
                r.conditions = a.conditions
                r.rejectedCitations = a.rejected.count
                r.detectedLanguage = detectLanguage(a.explanation)
                r.unsupportedNumbers = unsupportedNumbers(in: a, question: q.question)
            } catch {
                r.error = error.localizedDescription
            }
            r.seconds = Date().timeIntervalSince(started)
            results.append(r)
        }

        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(16).replacingOccurrences(of: ":", with: "")
        let name = "\(stamp)-\(engine.provider.displayName.replacingOccurrences(of: " · ", with: "-").replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_"))"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let jsonl = try results.map { String(decoding: try encoder.encode($0), as: UTF8.self) }.joined(separator: "\n")
        try jsonl.write(to: out.appendingPathComponent("\(name).jsonl"), atomically: true, encoding: .utf8)
        let summary = markdown(results, model: engine.provider.displayName)
        try summary.write(to: out.appendingPathComponent("\(name).md"), atomically: true, encoding: .utf8)
        print("\n" + summary.components(separatedBy: "\n## ").first!)
        print("Report: \(out.appendingPathComponent("\(name).md").path)")
        try appendHistory(results, model: engine.provider.displayName, out: out)
    }

    /// One line per run in eval/history.csv, so results can be compared over time and across commits.
    static func appendHistory(_ rs: [EvalResult], model: String, out: URL) throws {
        let file = out.deletingLastPathComponent().appendingPathComponent("history.csv")
        if !FileManager.default.fileExists(atPath: file.path) {
            try "date,commit,model,questions,retrieval,citation,refusal,route,language,removed_citations,unsupported_numbers,errors,median_seconds\n"
                .write(to: file, atomically: true, encoding: .utf8)
        }
        let answerable = rs.filter { !$0.shouldRefuse }
        let answered = rs.filter { !$0.refused && $0.actualRoute == "law" }
        func rate(_ n: Int, _ d: Int) -> String { d == 0 ? "" : String(format: "%.3f", Double(n) / Double(d)) }
        let commit = (try? shell("git", "rev-parse", "--short", "HEAD")) ?? ""
        let fields = [
            ISO8601DateFormatter().string(from: Date()), commit, model.replacingOccurrences(of: ",", with: " "), "\(rs.count)",
            rate(answerable.filter(\.retrievalHit).count, answerable.count),
            rate(answerable.filter(\.citationHit).count, answerable.count),
            rate(rs.filter(\.refusalCorrect).count, rs.count),
            rate(rs.filter(\.routeCorrect).count, rs.count),
            rate(answered.filter(\.languageCorrect).count, answered.count),
            rate(rs.filter { $0.rejectedCitations > 0 }.count, rs.count),
            rate(answered.filter { !$0.unsupportedNumbers.isEmpty }.count, answered.count),
            "\(rs.filter { $0.error != nil }.count)",
            String(format: "%.1f", rs.map(\.seconds).sorted()[rs.count / 2]),
        ]
        let handle = try FileHandle(forWritingTo: file)
        handle.seekToEndOfFile()
        handle.write(Data((fields.joined(separator: ",") + "\n").utf8))
        try handle.close()
        print("Appended to \(file.path)")
    }

    static func shell(_ args: String...) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func detectLanguage(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        return NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
    }

    static func unsupportedNumbers(in a: Answer, question: String) -> [String] {
        let support = (a.citations.map(\.passage.paragraph.text) + [question]).joined(separator: " ")
        let claimed = ([a.explanation] + a.conditions).joined(separator: " ")
        let numbers = Set(claimed.matches(of: /\d+(?:[.,]\d+)?/).map { String($0.output) })
        return numbers.filter { !support.contains($0) }.sorted()
    }

    static func markdown(_ rs: [EvalResult], model: String) -> String {
        func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : String(format: "%d/%d (%.0f%%)", n, d, 100 * Double(n) / Double(d)) }
        let answerable = rs.filter { !$0.shouldRefuse }
        let answered = rs.filter { !$0.refused }
        var md = """
        # Evaluation: \(model)

        | Measure | Result |
        |---|---|
        | Retrieval found a gold section | \(pct(answerable.filter(\.retrievalHit).count, answerable.count)) |
        | Citation accuracy (cited a gold section) | \(pct(answerable.filter(\.citationHit).count, answerable.count)) |
        | Refusal correctness | \(pct(rs.filter(\.refusalCorrect).count, rs.count)) |
        | Routing correctness | \(pct(rs.filter(\.routeCorrect).count, rs.count)) |
        | Wrongly refused | \(answerable.filter(\.refused).count) |
        | Wrongly answered | \(rs.filter { $0.shouldRefuse && !$0.refused }.count) |
        | Language fidelity (answered in requested language) | \(pct(answered.filter(\.languageCorrect).count, answered.count)) |
        | Answers with removed citations | \(pct(rs.filter { $0.rejectedCitations > 0 }.count, rs.count)) |
        | Answers with unsupported numbers | \(pct(answered.filter { !$0.unsupportedNumbers.isEmpty }.count, answered.count)) |
        | Errors | \(rs.filter { $0.error != nil }.count) |
        | Median seconds per question | \(String(format: "%.1f", rs.map(\.seconds).sorted()[rs.count / 2])) |

        Answer correctness: grade each answer below against its reference by hand.

        """
        for r in rs {
            md += """

            ## \(r.id) (\(r.lang)) \(r.citationHit ? "✅" : r.refusalCorrect && r.shouldRefuse ? "✅" : "❌")

            **Q:** \(r.question)

            **Gold:** \(r.gold.isEmpty ? "should refuse" : r.gold.joined(separator: ", ")) · **Cited:** \(r.cited.joined(separator: ", ").isEmpty ? "–" : r.cited.joined(separator: ", ")) · **Retrieved:** \(r.retrieved.prefix(8).joined(separator: ", "))

            **Answer:** \(r.error.map { "ERROR: \($0)" } ?? (r.refused ? "(refused)" : r.explanation))
            \(r.conditions.map { "- [ ] \($0)" }.joined(separator: "\n"))

            **Reference:** \(r.reference)
            \(r.unsupportedNumbers.isEmpty ? "" : "\n**Unsupported numbers:** \(r.unsupportedNumbers.joined(separator: ", "))")
            \(r.rejectedCitations > 0 ? "**Removed citations:** \(r.rejectedCitations)" : "")

            """
        }
        return md
    }
}
