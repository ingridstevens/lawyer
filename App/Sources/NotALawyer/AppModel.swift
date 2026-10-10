import Foundation
import NotALawyerApple
import NotALawyerCore
import Observation
import SwiftUI

/// Which model answers. Persisted in settings.
enum ProviderChoice: Codable, Hashable {
    case apple
    case localServer(kind: LocalServerProvider.Kind, baseURL: URL, model: String)
}

/// Everything the app stores apart from documents. Lives only in the app's
/// Application Support folder (spec §5, §11).
struct StoredSettings: Codable {
    var acknowledgedDisclaimer = false
    var finishedOnboarding = false
    var preferences = AnswerPreferences()
    var situation = Situation()
    var provider: ProviderChoice = .apple
    /// Notes the user asked the app to keep in mind.
    var memories: [MemoryNote] = []
    /// Ticked plan items, by plan ID.
    var planProgress: [String: Set<String>] = [:]
    /// Why the user ticked a plan item: by plan ID, then step ID.
    var planProof: [String: [String: StepProof]] = [:]
    /// What the app calls the user. Only shown in the app, never sent to the model.
    var preferredName = ""
    var avatar: CatAvatar.Fur = .mike
    /// Keep normal chats on this Mac between launches. Ghost chats are never kept.
    var keepChats = true
    /// Seconds per answer, last 10, by model name. Shown in the model advisor.
    var answerTimes: [String: [Double]] = [:]

    init() {}

    init(from decoder: any Decoder) throws {
        // Tolerate settings written by older builds: anything unreadable falls back to its default.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = StoredSettings()
        acknowledgedDisclaimer = (try? c.decode(Bool.self, forKey: .acknowledgedDisclaimer)) ?? d.acknowledgedDisclaimer
        finishedOnboarding = (try? c.decode(Bool.self, forKey: .finishedOnboarding)) ?? d.finishedOnboarding
        preferences = (try? c.decode(AnswerPreferences.self, forKey: .preferences)) ?? d.preferences
        situation = (try? c.decode(Situation.self, forKey: .situation)) ?? d.situation
        provider = (try? c.decode(ProviderChoice.self, forKey: .provider)) ?? d.provider
        memories = (try? c.decode([MemoryNote].self, forKey: .memories)) ?? d.memories
        planProgress = (try? c.decode([String: Set<String>].self, forKey: .planProgress)) ?? d.planProgress
        preferredName = (try? c.decode(String.self, forKey: .preferredName)) ?? d.preferredName
        avatar = (try? c.decode(CatAvatar.Fur.self, forKey: .avatar)) ?? d.avatar
        keepChats = (try? c.decode(Bool.self, forKey: .keepChats)) ?? d.keepChats
        answerTimes = (try? c.decode([String: [Double]].self, forKey: .answerTimes)) ?? d.answerTimes
        planProof = (try? c.decode([String: [String: StepProof]].self, forKey: .planProof)) ?? d.planProof
    }
}

/// The user's support for ticking a plan item: documents they hold and/or their own reason.
struct StepProof: Codable, Hashable {
    var documentIDs: [UUID] = []
    var note = ""
    var date = Date()

    var isEmpty: Bool { documentIDs.isEmpty && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct MemoryNote: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var added = Date()
}

/// One question and what came back.
struct Exchange: Identifiable, Codable {
    enum State: Codable {
        case thinking(AnswerStage)
        case answered(Answer)
        case failed(String)

        private enum Key: String, CodingKey { case answered, failed }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            if let answer = try? c.decode(Answer.self, forKey: .answered) { self = .answered(answer) }
            else { self = .failed((try? c.decode(String.self, forKey: .failed)) ?? "This answer couldn't be loaded.") }
        }

        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: Key.self)
            switch self {
            case .answered(let answer): try c.encode(answer, forKey: .answered)
            case .failed(let message): try c.encode(message, forKey: .failed)
            // A question still running when the app quits is saved as interrupted.
            case .thinking: try c.encode("Interrupted when the app closed. Ask it again.", forKey: .failed)
            }
        }
    }

    var id = UUID()
    var question: String
    /// False for a general question: the situation, memory and documents are left out.
    var personal: Bool
    var state: State
    /// The model that's answering, or answered, this question.
    var modelName = ""
    var seconds: Double?
}

/// A conversation. Several can run at once; each keeps its own questions.
struct Chat: Identifiable, Codable {
    var id = UUID()
    var title = "New chat"
    /// True once the user has named it; otherwise the first question becomes the title.
    var renamed = false
    /// Ghost chat: the situation, memory and documents are left out of every question.
    var ghost = false
    /// What this chat is working towards; every question is answered with it in mind.
    var goal: Situation.Goal?
    /// The user's notes for this chat only, e.g. "I studied in Germany 2018–2021".
    var context = ""
    var exchanges: [Exchange] = []
}

enum SidebarItem: Hashable {
    case chat(UUID)
    case documents
    case plan(String)
    case helpResources
    case prepareContact
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case situation, memory, model, language, laws, privacy
    var id: Self { self }

    /// Grouped like System Settings: what's about the user, then how the app works.
    static let you: [SettingsTab] = [.situation, .memory]
    static let app: [SettingsTab] = [.model, .language, .laws, .privacy]

    var subtitle: String {
        switch self {
        case .situation: "Your name, your cat, and your situation. Used to find the right rules, never to decide your case."
        case .memory: "Things you've asked the app to keep in mind in personal chats."
        case .model: "Which model on this Mac writes the explanations, and which ones suit this Mac."
        case .language: "The language answers are in, and how they're explained."
        case .laws: "The official texts the app quotes, and when they were last checked."
        case .privacy: "What's stored, where, and every connection the app has made."
        }
    }


    var title: String {
        switch self {
        case .model: "Model"
        case .language: "Language"
        case .situation: "You"
        case .memory: "Memory"
        case .laws: "Laws"
        case .privacy: "Privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .model: "cpu.fill"
        case .language: "character.bubble"
        case .situation: "person.fill"
        case .memory: "brain.head.profile"
        case .laws: "book.closed.fill"
        case .privacy: "lock.fill"
        }
    }
}

@MainActor @Observable
final class AppModel {
    var settings: StoredSettings { didSet { save() } }
    var chats: [Chat] = [Chat()] { didSet { scheduleChatSave() } }
    let documents = DocumentStore(directory: AppModel.supportDirectory.appendingPathComponent("Documents", isDirectory: true))

    // Navigation.
    var sidebarSelection: SidebarItem = .documents
    var scrollTarget: UUID?
    var settingsTab: SettingsTab?
    var importingDocument = false
    /// The type to file the next added documents under, when the user picked one first.
    var importKind: DocumentKind?

    /// Document types the user's plans usually need and that they haven't added yet.
    var missingDocumentKinds: [DocumentKind] {
        let have = Set(documents.records.map(\.kind))
        var seen = Set<DocumentKind>()
        return visiblePlans.flatMap(\.steps).flatMap(\.documentKinds)
            .compactMap(DocumentKind.init(rawValue:))
            .filter { !have.contains($0) && $0 != .application && seen.insert($0).inserted }
    }
    var showingQuiz = false

    private(set) var index: LawIndex?
    private(set) var loadError: String?
    private(set) var isUpdatingLaws = false
    var lawUpdateMessage: String?

    /// The stale-law banner shows once the collection is older than this (spec §6, step 7).
    static let staleAfterDays = 90

    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Not a Lawyer", isDirectory: true)
    }()
    static var settingsFile: URL { supportDirectory.appendingPathComponent("settings.json") }
    /// Laws downloaded by "Update laws". Used instead of the bundled snapshot when present.
    static var downloadedLawsDirectory: URL { supportDirectory.appendingPathComponent("laws", isDirectory: true) }

    init() {
        settings = Self.loadSettings()
        syncSharedConditions()
        if settings.keepChats, let saved = Self.loadChats(), !saved.isEmpty { chats = saved + [Chat()] }
        sidebarSelection = .chat(chats[0].id)
        startNetworkLog()
        Task { await loadLaws() }
    }

    // MARK: Laws

    /// The snapshot shipped inside the app, or data/snapshot when running from the repo.
    static var bundledLawsDirectory: URL {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("laws"),
           FileManager.default.fileExists(atPath: url.path) { return url }
        if let env = ProcessInfo.processInfo.environment["NAL_LAWS"] { return URL(fileURLWithPath: env) }
        return URL(fileURLWithPath: "data/snapshot")
    }

    func loadLaws() async {
        let downloaded = Self.downloadedLawsDirectory
        let directory = FileManager.default.fileExists(atPath: downloaded.path) ? downloaded : Self.bundledLawsDirectory
        do {
            index = try await Task.detached { try LawIndex(directory: directory) }.value
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Stale means not checked against the official site for a while. A law's own date can be
    /// old simply because it hasn't changed, so it isn't used for this.
    var lawsAreStale: Bool {
        guard let checked = index?.checkedAt else { return false }
        return Date().timeIntervalSince(checked) > Double(Self.staleAfterDays) * 86_400
    }

    // MARK: Network log

    /// Every connection the app made this session, newest first (see `NetworkPolicy`).
    private(set) var networkLog: [NetworkPolicy.Entry] = []

    func startNetworkLog() {
        networkLog = NetworkPolicy.log
        NetworkPolicy.onRecord = { _ in
            Task { @MainActor [weak self] in self?.networkLog = NetworkPolicy.log }
        }
    }

    /// Whether FileVault encrypts this Mac's disk. nil if it couldn't be checked.
    nonisolated static func fileVaultIsOn() -> Bool? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        p.arguments = ["status"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        if out.contains("FileVault is On") { return true }
        if out.contains("FileVault is Off") { return false }
        return nil
    }

    /// The app's only connection to the internet, and only when the user asks (spec §8, §11).
    func updateLaws() async {
        isUpdatingLaws = true
        lawUpdateMessage = nil
        defer { isUpdatingLaws = false }
        do {
            try await LawUpdater.update(into: Self.downloadedLawsDirectory)
            await loadLaws()
            lawUpdateMessage = "Laws updated to the text as of \(index?.asOf.lawDate ?? "today")."
        } catch {
            lawUpdateMessage = "Update failed: \(error.localizedDescription)"
        }
    }

    // MARK: Model

    func makeProvider() throws -> any ModelProvider {
        switch settings.provider {
        case .apple:
            guard FoundationModelsProvider.isAvailable else {
                throw AppError(FoundationModelsProvider.unavailableReason ?? "Apple's model isn't available. Choose a local model in Settings → Model.")
            }
            return FoundationModelsProvider()
        case let .localServer(kind, baseURL, model):
            guard !model.isEmpty else { throw AppError("No model is chosen yet. Choose one in Settings → Model.") }
            return try LocalServerProvider(kind: kind, baseURL: baseURL, model: model)
        }
    }

    var providerName: String {
        switch settings.provider {
        case .apple: "Apple on-device model"
        case let .localServer(_, _, model): model.isEmpty ? "No model chosen" : model
        }
    }

    /// Set when the chosen language isn't supported by the active model (spec §7).
    var languageWarning: String? {
        guard case .apple = settings.provider else { return nil }
        let code = settings.preferences.languageCode
        guard !FoundationModelsProvider.supportsLanguage(code) else { return nil }
        return "Apple's on-device model doesn't support \(settings.preferences.languageName), so answers may be poor or in another language. Choose a local model in Settings → Model, or another language."
    }

    // MARK: Asking

    // MARK: Chats

    /// The chat on screen, or the most recent one.
    var currentChatID: UUID {
        if case .chat(let id) = sidebarSelection, chats.contains(where: { $0.id == id }) { return id }
        return chats.last!.id
    }

    var currentChat: Chat { chats.first { $0.id == currentChatID }! }

    /// Questions in the chat on screen.
    var exchanges: [Exchange] { currentChat.exchanges }

    func newChat(ghost: Bool = false) {
        // Reuse an empty chat instead of piling them up.
        // Only an empty chat of the same kind, so a ghost chat is never turned back into a normal one.
        if let empty = chats.first(where: { $0.exchanges.isEmpty && $0.ghost == ghost }) {
            sidebarSelection = .chat(empty.id)
            return
        }
        var chat = Chat(ghost: ghost)
        // A new personal chat starts with the user's first goal; they can change it.
        if !ghost { chat.goal = Situation.Goal.allCases.first { settings.situation.goals.contains($0) } }
        chats.append(chat)
        sidebarSelection = .chat(chat.id)
    }

    func renameChat(_ id: UUID, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        updateChat(id) { $0.title = t; $0.renamed = true }
    }

    func deleteChat(_ id: UUID) {
        for e in chats.first(where: { $0.id == id })?.exchanges ?? [] { tasks[e.id]?.cancel() }
        chats.removeAll { $0.id == id }
        if chats.isEmpty { chats = [Chat()] }
        if case .chat(let selected) = sidebarSelection, selected == id { sidebarSelection = .chat(chats.last!.id) }
    }

    /// One way only, and only before the first question: a chat can become a ghost chat, but a
    /// ghost chat never goes back to using the user's details.
    func setGoal(_ goal: Situation.Goal?, for id: UUID) { updateChat(id) { $0.goal = goal } }
    func setContext(_ text: String, for id: UUID) { updateChat(id) { $0.context = text } }

    func setGhost(_ ghost: Bool, for id: UUID) {
        guard ghost else { return }
        updateChat(id) { chat in if chat.exchanges.isEmpty { chat.ghost = true } }
    }

    private func updateChat(_ id: UUID, _ change: (inout Chat) -> Void) {
        guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
        change(&chats[i])
    }

    /// Finds a question in any chat; answers can arrive after the user has switched chats.
    private func updateExchange(_ id: UUID, _ change: (inout Exchange) -> Void) {
        for c in chats.indices {
            if let e = chats[c].exchanges.firstIndex(where: { $0.id == id }) { change(&chats[c].exchanges[e]); return }
        }
    }

    private func exchange(_ id: UUID) -> Exchange? {
        chats.lazy.flatMap(\.exchanges).first { $0.id == id }
    }

    // MARK: Asking

    /// Asks in the chat on screen.
    func ask(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let chatID = currentChatID
        let exchange = Exchange(question: trimmed, personal: !currentChat.ghost, state: .thinking(.searching))
        updateChat(chatID) { chat in
            chat.exchanges.append(exchange)
            if !chat.renamed && chat.exchanges.count == 1 { chat.title = String(trimmed.prefix(60)) }
        }
        sidebarSelection = .chat(chatID)
        run(exchange.id)
    }

    /// Replaces a question with an edited one and answers it again.
    func reask(_ id: UUID, as question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, exchange(id) != nil else { return }
        updateExchange(id) { $0.question = trimmed; $0.state = .thinking(.searching) }
        run(id)
    }

    func remove(_ id: UUID) {
        stop(id)
        for c in chats.indices { chats[c].exchanges.removeAll { $0.id == id } }
    }

    /// Running questions, so they can be stopped.
    private var tasks: [UUID: Task<Void, Never>] = [:]
    /// One question at a time per model: local servers like Ollama answer one request at a time
    /// anyway, and this way a waiting question can say so instead of looking slow.
    private let gate = ModelGate()

    func stop(_ id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        updateExchange(id) { e in if case .thinking = e.state { e.state = .failed("Stopped.") } }
    }

    private func run(_ id: UUID) {
        guard exchange(id) != nil else { return }
        tasks[id]?.cancel()
        // The model is fixed when the question starts; switching models later doesn't affect it.
        let modelName = providerName
        updateExchange(id) { $0.modelName = modelName; $0.seconds = nil }
        let exchange = exchange(id)!
        let question = exchange.question
        let preferences = settings.preferences
        let situation = exchange.personal ? settings.situation : Situation()
        let memory = exchange.personal ? settings.memories.map(\.text) : []
        let conversation = conversationContext(before: id)
        let started = Date()
        tasks[id] = Task {
            if await gate.isBusy(modelName) { setStage(.queued, for: id) }
            await gate.acquire(modelName)
            defer { Task { await gate.release(modelName) } }
            guard !Task.isCancelled else { return }
            setStage(.searching, for: id)
            let state: Exchange.State
            do {
                guard let index else { throw AppError(loadError ?? "The laws are still loading. Try again in a moment.") }
                let engine = AnswerEngine(index: index, provider: try makeProvider())
                state = .answered(try await engine.ask(question, preferences: preferences, situation: situation, memory: memory,
                                                       conversation: conversation) { stage in
                    Task { @MainActor in self.setStage(stage, for: id) }
                })
            } catch {
                state = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled else { return }
            tasks[id] = nil
            // Ignore a result for a question that was edited or removed meanwhile.
            guard self.exchange(id)?.question == question else { return }
            let seconds = Date().timeIntervalSince(started)
            updateExchange(id) { $0.state = state; $0.seconds = seconds }
            if case .answered(let a) = state, a.route == .law {
                settings.answerTimes[modelName] = Array(((settings.answerTimes[modelName] ?? []) + [seconds]).suffix(10))
            }
        }
    }

    /// The chat's goal, notes and up to three earlier answered questions, for a follow-up.
    private func conversationContext(before id: UUID) -> ConversationContext {
        guard let chat = chats.first(where: { $0.exchanges.contains { $0.id == id } }),
              let position = chat.exchanges.firstIndex(where: { $0.id == id }) else { return ConversationContext() }
        let earlier = chat.exchanges[..<position].suffix(3).compactMap { e -> ConversationContext.EarlierTurn? in
            guard case .answered(let a) = e.state, a.route == .law else { return nil }
            var labels: [String] = []
            for c in a.citations where !labels.contains(c.passage.section.label) { labels.append(c.passage.section.label) }
            return .init(question: e.question, sections: labels)
        }
        return ConversationContext(goal: chat.goal.map { "\($0.german) (\($0.english))" },
                                   notes: chat.context.trimmingCharacters(in: .whitespacesAndNewlines),
                                   earlier: Array(earlier))
    }

    func setStage(_ stage: AnswerStage, for id: UUID) {
        updateExchange(id) { e in if case .thinking = e.state { e.state = .thinking(stage) } }
    }

    // MARK: Memory and plans

    func remember(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.memories.insert(MemoryNote(text: trimmed), at: 0)
    }

    func isDone(_ step: PlanStep, in plan: Plan) -> Bool { settings.planProgress[plan.id]?.contains(step.id) ?? false }

    /// Ticking needs proof: at least one document or a written reason. Unticking removes it.
    /// A condition that appears in several plans (B1 German, living space…) is ticked or
    /// unticked in all of them at once.
    func setDone(_ done: Bool, _ step: PlanStep, in plan: Plan, proof: StepProof? = nil) {
        let targets = step.shared == nil ? [(plan, step)] : Plan.sameCondition(as: step)
        for (p, s) in targets {
            var set = settings.planProgress[p.id] ?? []
            if done, let proof, !proof.isEmpty {
                set.insert(s.id)
                settings.planProof[p.id, default: [:]][s.id] = proof
            } else if !done {
                set.remove(s.id)
                settings.planProof[p.id]?[s.id] = nil
            }
            settings.planProgress[p.id] = set
        }
    }

    /// Carries ticks made before conditions were linked across plans over to the other plans.
    func syncSharedConditions() {
        for plan in Plan.all {
            for step in plan.steps where step.shared != nil && isDone(step, in: plan) {
                guard let proof = proof(for: step, in: plan) else { continue }
                for (p, s) in Plan.sameCondition(as: step) where !isDone(s, in: p) {
                    settings.planProgress[p.id, default: []].insert(s.id)
                    settings.planProof[p.id, default: [:]][s.id] = proof
                }
            }
        }
    }

    /// Proof given for other plan items, offered for reuse when ticking a similar one.
    func otherProofs(excluding step: PlanStep, in plan: Plan) -> [(title: String, plan: String, proof: StepProof)] {
        var seen = Set<StepProof>()
        return Plan.all.flatMap { p in
            p.steps.compactMap { s -> (String, String, StepProof)? in
                guard !(p.id == plan.id && s.id == step.id), let proof = proof(for: s, in: p), seen.insert(proof).inserted else { return nil }
                return (s.title, p.german, proof)
            }
        }
        .map { (title: $0.0, plan: $0.1, proof: $0.2) }
    }

    func proof(for step: PlanStep, in plan: Plan) -> StepProof? { settings.planProof[plan.id]?[step.id] }

    /// Opens a chat and asks what a plan item means, with the law it cites.
    func explain(_ step: PlanStep, in plan: Plan) {
        newChat()
        let refs = step.refs.map(\.label).joined(separator: " and ")
        ask("What does “\(step.german)” mean in \(refs)? Explain it for the plan “\(plan.german)”.")
    }

    /// Plans for the user's goals, or all of them if no goal is set.
    var visiblePlans: [Plan] {
        let suggested = Plan.suggested(for: settings.situation)
        return suggested.isEmpty ? Plan.all : suggested
    }

    // MARK: Privacy

    /// Removes the profile, settings, documents, downloaded laws and this session's questions (spec §11).
    func deleteEverything() {
        try? FileManager.default.removeItem(at: Self.supportDirectory)
        for task in tasks.values { task.cancel() }
        tasks = [:]
        chats = [Chat()]
        sidebarSelection = .chat(chats[0].id)
        documents.reload()
        settings = StoredSettings()
        settingsTab = nil
        Task { await loadLaws() }
    }

    /// Settings and the list of documents, as JSON. The documents themselves stay where they are.
    func exportData() throws -> Data {
        struct Export: Encodable { let settings: StoredSettings; let documents: [DocumentRecord] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Export(settings: settings, documents: documents.records))
    }

    // MARK: Chat storage

    static var chatsFile: URL { supportDirectory.appendingPathComponent("chats.json") }
    private var chatSaveTask: Task<Void, Never>?

    /// Saves a moment after the last change, so a streaming answer doesn't write on every update.
    private func scheduleChatSave() {
        chatSaveTask?.cancel()
        chatSaveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            saveChats()
        }
    }

    func saveChats() {
        guard settings.keepChats else { try? FileManager.default.removeItem(at: Self.chatsFile); return }
        // Ghost chats and empty chats are never written down.
        let keep = chats.filter { !$0.ghost && !$0.exchanges.isEmpty }
        do {
            try FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(keep).write(to: Self.chatsFile, options: [.atomic, .completeFileProtection])
        } catch {
            // Chats stay in memory for this session either way.
        }
    }

    private static func loadChats() -> [Chat]? {
        guard let data = try? Data(contentsOf: chatsFile) else { return nil }
        return try? JSONDecoder().decode([Chat].self, from: data)
    }

    func deleteAllChats() {
        for task in tasks.values { task.cancel() }
        tasks = [:]
        chats = [Chat()]
        sidebarSelection = .chat(chats[0].id)
        try? FileManager.default.removeItem(at: Self.chatsFile)
    }

    // MARK: Storage

    private static func loadSettings() -> StoredSettings {
        guard let data = try? Data(contentsOf: settingsFile),
              let settings = try? JSONDecoder().decode(StoredSettings.self, from: data) else { return StoredSettings() }
        return settings
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(settings).write(to: Self.settingsFile, options: [.atomic, .completeFileProtection])
        } catch {
            // Settings are a convenience; failing to save must not interrupt the user.
        }
    }
}

struct AppError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// Lets one question at a time use a model; the others wait in order.
actor ModelGate {
    private var busy: Set<String> = []
    private var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]

    func isBusy(_ model: String) -> Bool { busy.contains(model) }

    func acquire(_ model: String) async {
        guard busy.contains(model) else { busy.insert(model); return }
        await withCheckedContinuation { waiting[model, default: []].append($0) }
    }

    func release(_ model: String) {
        if var queue = waiting[model], !queue.isEmpty {
            let next = queue.removeFirst()
            waiting[model] = queue
            next.resume()
        } else {
            busy.remove(model)
        }
    }
}
