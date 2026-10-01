import Foundation
import NotALawyerApple
import NotALawyerCore

// Headless runner (spec §10).
//
//   nal-eval ask "<question>" [--model apple|ollama:<name>|lmstudio:<name>] [--lang en]
//   nal-eval run [--model …] [--questions eval/questions.jsonl] [--out eval/results]
//
// Run from the repo root, or pass --laws <dir>.

var args = Array(CommandLine.arguments.dropFirst())

@MainActor func option(_ name: String, default value: String) -> String {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return value }
    let v = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return v
}

func makeProvider(_ spec: String) throws -> any ModelProvider {
    if spec == "apple" { return FoundationModelsProvider() }
    let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { throw CLIError("Model must be apple, ollama:<name> or lmstudio:<name>") }
    let kind: LocalServerProvider.Kind = switch parts[0] {
    case "ollama": .ollama
    case "lmstudio": .lmStudio
    case "llamacpp": .llamaCpp
    default: throw CLIError("Unknown server \(parts[0])")
    }
    return try LocalServerProvider(kind: kind, model: parts[1])
}

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

let modelSpec = option("--model", default: "apple")
let lawsDir = option("--laws", default: "data/snapshot")
let language = option("--lang", default: "en")
let questionsPath = option("--questions", default: "eval/questions.jsonl")
let outDir = option("--out", default: "eval/results")
let command = args.first ?? "help"

do {
    let index = try LawIndex(directory: URL(fileURLWithPath: lawsDir))
    let engine = AnswerEngine(index: index, provider: try makeProvider(modelSpec))

    switch command {
    case "ask":
        guard args.count >= 2 else { throw CLIError("Usage: nal-eval ask \"<question>\"") }
        let started = Date()
        let answer = try await engine.ask(args[1], preferences: AnswerPreferences(languageCode: language))
        print(Report.text(answer))
        print(String(format: "\n(%.1fs, %@)", Date().timeIntervalSince(started), engine.provider.displayName))
    case "terms":
        print(try await engine.provider.plan(args[1]))
    case "run":
        try await Evaluation.run(engine: engine, questions: URL(fileURLWithPath: questionsPath),
                                 out: URL(fileURLWithPath: outDir))
    default:
        print("Usage: nal-eval ask \"<question>\" | run   [--model apple|ollama:<name>] [--lang en]")
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
