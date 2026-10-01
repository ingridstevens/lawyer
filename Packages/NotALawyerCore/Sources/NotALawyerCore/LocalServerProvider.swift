import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A model server running on this computer (spec §7).
///
/// LM Studio and llama.cpp are spoken to through their OpenAI-compatible API. Ollama uses
/// its native API instead, because only that lets us raise the context window: Ollama's
/// default is a few thousand tokens and it silently cuts off longer prompts.
public struct LocalServerProvider: ModelProvider {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case ollama, lmStudio, llamaCpp, openAICompatible

        public var displayName: String {
            switch self {
            case .ollama: "Ollama"
            case .lmStudio: "LM Studio"
            case .llamaCpp: "llama.cpp"
            case .openAICompatible: "Other (OpenAI-compatible)"
            }
        }

        public var defaultBaseURL: URL {
            switch self {
            case .ollama: URL(string: "http://localhost:11434")!
            case .lmStudio: URL(string: "http://localhost:1234/v1")!
            case .llamaCpp, .openAICompatible: URL(string: "http://localhost:8080/v1")!
            }
        }
    }

    public let kind: Kind
    public let baseURL: URL
    public let model: String
    /// Context window to request from Ollama, in tokens.
    public var contextTokens = 8_192
    /// Longest answer we let a model write.
    public var maxAnswerTokens = 1_600

    public var displayName: String { "\(kind.displayName) · \(model)" }
    /// Characters of law text per question. German legal text runs at roughly 2.5 characters per
    /// token, and the instructions take ~1,500 tokens, so this leaves ~3,000 tokens for the answer.
    /// The old budget (~15,000 characters) left so little room that answers were cut off mid-JSON,
    /// and reading that much text was most of the wait.
    public var contextBudget: Int { max(4_000, Int(Double(contextTokens - 4_500) * 2.5)) }

    public init(kind: Kind, baseURL: URL? = nil, model: String) throws {
        let url = baseURL ?? kind.defaultBaseURL
        guard Self.isLocal(url) else { throw LocalServerError.notLocalhost(url) }
        self.kind = kind
        self.baseURL = url
        self.model = model
    }

    /// Only this computer: questions must never reach another machine by accident.
    public static func isLocal(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
    }

    // MARK: Model list and connection test

    /// Models the server offers. Also serves as the "test connection" check.
    public static func availableModels(kind: Kind, baseURL: URL? = nil) async throws -> [String] {
        let base = baseURL ?? kind.defaultBaseURL
        guard isLocal(base) else { throw LocalServerError.notLocalhost(base) }
        if kind == .ollama {
            let data = try await get(base.appendingPathComponent("api/tags"))
            struct Tags: Decodable { struct M: Decodable { let name: String }; let models: [M] }
            return try JSONDecoder().decode(Tags.self, from: data).models.map(\.name).sorted()
        } else {
            let data = try await get(base.appendingPathComponent("models"))
            struct Models: Decodable { struct M: Decodable { let id: String }; let data: [M] }
            return try JSONDecoder().decode(Models.self, from: data).data.map(\.id).sorted()
        }
    }

    // MARK: Ollama model downloads

    /// Ollama's version, or nil if it isn't running on this Mac.
    public static func ollamaVersion(baseURL: URL = Kind.ollama.defaultBaseURL) async -> String? {
        struct V: Decodable { let version: String }
        guard let data = try? await get(baseURL.appendingPathComponent("api/version")) else { return nil }
        return try? JSONDecoder().decode(V.self, from: data).version
    }

    /// Downloads a model through the local Ollama. `progress` gets a fraction (nil while
    /// Ollama is preparing) and Ollama's status text.
    public static func pullOllamaModel(_ name: String, baseURL: URL = Kind.ollama.defaultBaseURL,
                                       progress: @Sendable (Double?, String) -> Void) async throws {
        guard isLocal(baseURL) else { throw LocalServerError.notLocalhost(baseURL) }
        try NetworkPolicy.check(baseURL, purpose: "Ollama on this Mac: download \(name)")
        var request = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": name, "stream": true])
        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw LocalServerError.http(http.statusCode, "")
        }
        struct Line: Decodable { let status: String?; let total: Int64?; let completed: Int64?; let error: String? }
        for try await line in bytes.lines {
            guard let event = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)) else { continue }
            if let error = event.error { throw LocalServerError.http(500, error) }
            let fraction = event.total.flatMap { t in t > 0 ? Double(event.completed ?? 0) / Double(t) : nil }
            progress(fraction, event.status ?? "")
        }
    }

    // MARK: ModelProvider

    public func plan(_ question: String) async throws -> QueryPlan {
        let json = try await complete(system: Prompts.planInstructions, user: question,
                                      schema: Prompts.planJSONSchema, schemaName: "plan")
        return try JSONDecoder().decode(QueryPlan.self, from: json)
    }

    public func answer(_ request: AnswerRequest) async throws -> ModelAnswer {
        let json = try await complete(system: Prompts.answerInstructions, user: Prompts.answerPrompt(request),
                                      schema: Prompts.answerJSONSchema, schemaName: "answer")
        do {
            return try JSONDecoder().decode(ModelAnswer.self, from: json)
        } catch where JSONRepair.repair(json) != nil {
            // Cut off mid-answer: keep the explanation, checklist and complete citations.
            return try JSONDecoder().decode(ModelAnswer.self, from: JSONRepair.repair(json)!)
        } catch {
            let text = String(data: json, encoding: .utf8) ?? ""
            if ProcessInfo.processInfo.environment["NAL_DEBUG"] != nil {
                FileHandle.standardError.write(Data("Unreadable answer (\(error)):\n\(text)\n".utf8))
            }
            throw LocalServerError.badAnswer(text)
        }
    }

    // MARK: HTTP

    /// Sends one chat turn and returns the JSON the model produced.
    func complete(system: String, user: String, schema: String, schemaName: String) async throws -> Data {
        let messages = [["role": "system", "content": system], ["role": "user", "content": user]]
        let content: String
        if kind == .ollama {
            let body: [String: Any] = [
                "model": model, "messages": messages, "stream": false, "format": Self.schemaPlaceholder, "think": false,
                // Capped and with a repetition penalty: small models otherwise loop on the same
                // citation until the window is full, and the JSON never closes.
                "options": ["temperature": 0, "num_ctx": contextTokens, "num_predict": maxAnswerTokens, "repeat_penalty": 1.15],
            ]
            let data = try await Self.post(baseURL.appendingPathComponent("api/chat"), body: body, schema: schema)
            struct Reply: Decodable { struct M: Decodable { let content: String }; let message: M }
            content = try JSONDecoder().decode(Reply.self, from: data).message.content
        } else {
            let body: [String: Any] = [
                "model": model, "messages": messages, "temperature": 0, "max_tokens": maxAnswerTokens, "frequency_penalty": 0.3,
                "response_format": ["type": "json_schema", "json_schema": ["name": schemaName, "schema": Self.schemaPlaceholder]],
            ]
            let data = try await Self.post(baseURL.appendingPathComponent("chat/completions"), body: body, schema: schema)
            struct Reply: Decodable {
                struct C: Decodable { struct M: Decodable { let content: String }; let message: M }
                let choices: [C]
            }
            content = try JSONDecoder().decode(Reply.self, from: data).choices.first?.message.content ?? ""
        }
        return Data(Self.extractJSON(content).utf8)
    }

    /// Some servers wrap JSON in a code fence even when asked for a schema.
    static func extractJSON(_ s: String) -> String {
        guard let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") else { return s }
        return String(s[start...end])
    }

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 600
        return URLSession(configuration: config)
    }()

    static func get(_ url: URL) async throws -> Data {
        try NetworkPolicy.check(url, purpose: "Model server on this Mac")
        let (data, response) = try await session.data(from: url)
        try check(response, data)
        return data
    }

    static let schemaPlaceholder = "__SCHEMA__"

    /// Posts `body`, with the placeholder string replaced by `schema` verbatim, so the schema's
    /// property order survives serialisation.
    static func post(_ url: URL, body: [String: Any], schema: String? = nil) async throws -> Data {
        try NetworkPolicy.check(url, purpose: "Model server on this Mac")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var json = String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self)
        if let schema { json = json.replacingOccurrences(of: "\"\(schemaPlaceholder)\"", with: schema) }
        request.httpBody = Data(json.utf8)
        let (data, response) = try await session.data(for: request)
        try check(response, data)
        return data
    }

    static func check(_ response: URLResponse, _ data: Data) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LocalServerError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}

public enum LocalServerError: Error, LocalizedError {
    case notLocalhost(URL)
    case http(Int, String)
    case badAnswer(String)

    public var errorDescription: String? {
        switch self {
        case .notLocalhost(let url): "Only servers on this computer are allowed (localhost or 127.0.0.1), not \(url.absoluteString)."
        case .http(let code, let body): "The model server answered with error \(code): \(body.prefix(300))"
        case .badAnswer(let text): "The model's answer wasn't in the expected format: \(text.prefix(300))"
        }
    }
}

/// Closes a JSON answer that was cut off, keeping everything complete before the cut.
enum JSONRepair {
    static func repair(_ data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        // Walk the text, tracking strings and nesting; remember the last point where an element of
        // an array or object had just finished.
        var stack: [Character] = []
        var inString = false, escaped = false
        var lastSafe: (index: String.Index, stack: [Character])?
        for i in text.indices {
            let ch = text[i]
            if inString {
                if escaped { escaped = false } else if ch == "\\" { escaped = true } else if ch == "\"" { inString = false }
                continue
            }
            switch ch {
            case "\"": inString = true
            case "{", "[": stack.append(ch)
            case "}", "]":
                guard !stack.isEmpty else { return nil }
                stack.removeLast()
                lastSafe = (text.index(after: i), stack)
            case "," where stack.last == "[":
                // Only between array items, so a half-written citation is dropped, not kept.
                lastSafe = (i, stack)
            default: break
            }
        }
        guard !stack.isEmpty else { return nil }
        // Best: cut back to the last complete item.
        if let safe = lastSafe {
            var fixed = String(text[..<safe.index])
            for opener in safe.stack.reversed() { fixed.append(opener == "{" ? "}" : "]") }
            if (try? JSONSerialization.jsonObject(with: Data(fixed.utf8))) != nil { return Data(fixed.utf8) }
        }
        // Cut inside the first string (usually the explanation): keep what was written.
        var fixed = text
        if inString { fixed += escaped ? "\\\"" : "\"" }
        for opener in stack.reversed() { fixed.append(opener == "{" ? "}" : "]") }
        guard (try? JSONSerialization.jsonObject(with: Data(fixed.utf8))) != nil else { return nil }
        return Data(fixed.utf8)
    }
}
