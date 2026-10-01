import NotALawyerApple
import NotALawyerCore
import SwiftUI
import UniformTypeIdentifiers

/// Settings as an overlay on the main window, with its own sidebar.
/// Settings as an overlay on the main window, laid out like System Settings: who you are at
/// the top of the sidebar, tabs grouped into "You" and "App", and a header on every pane.
struct SettingsPanel: View {
    @Environment(AppModel.self) private var model

    private var tab: SettingsTab { model.settingsTab ?? .situation }

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                profileHeader
                    .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 10)
                List(selection: $model.settingsTab) {
                    Section("Personal") { ForEach(SettingsTab.you) { row($0) } }
                    Section("App") { ForEach(SettingsTab.app) { row($0) } }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .tint(Theme.stamp)
            }
            .frame(width: 230)
            .background(Color.secondary.opacity(0.06))

            Divider()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(tab: tab, size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title(tab)).font(.title2.weight(.semibold))
                        Text(tab.subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button { model.settingsTab = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                            .frame(width: 24, height: 24).background(Circle().fill(Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 8)

                Group {
                    switch tab {
                    case .model: ModelSettings()
                    case .language: Form { LanguageSettings() }.formStyle(.grouped)
                    case .situation: SituationTab()
                    case .memory: MemorySettings()
                    case .laws: LawSettings()
                    case .privacy: PrivacySettings()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Image(systemName: "lock.fill").font(.caption2)
                    Text("Changes are saved as you make them, only on this Mac.")
                    Spacer()
                    Button("Done") { model.settingsTab = nil }.keyboardShortcut(.defaultAction)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.vertical, 12)
            }
        }
        .frame(width: 900, height: 660)
    }

    private func row(_ tab: SettingsTab) -> some View {
        Label { Text(title(tab)) } icon: { IconTile(tab: tab, size: 22) }
            .tag(tab)
    }

    /// The "You" tab carries the user's name once they've given one.
    private func title(_ tab: SettingsTab) -> String {
        tab == .situation && !model.settings.preferredName.isEmpty ? model.settings.preferredName : tab.title
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            CatAvatar(fur: model.settings.avatar, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.settings.preferredName.isEmpty ? "You" : model.settings.preferredName)
                    .font(.headline)
                Text(model.settings.situation.status?.german ?? "Situation not set up")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(model.providerName)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

/// A rounded icon tile in one quiet grey, so the settings list stays calm.
struct IconTile: View {
    @Environment(AppModel.self) private var model
    let tab: SettingsTab
    var size: CGFloat = 22

    var body: some View {
        // "You" is the user's profile, so it shows their cat, as in the profile header and corner.
        if tab == .situation {
            CatAvatar(fur: model.settings.avatar, size: size)
        } else {
            symbol
        }
    }

    private var symbol: some View {
        Image(systemName: tab.systemImage)
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(Theme.ink.opacity(0.75))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.24).fill(Color.secondary.opacity(0.14)))
            .accessibilityHidden(true)
    }
}

struct SituationTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Answer a few questions instead of filling in the form.")
                    Spacer()
                    Button("Start guided setup") {
                        model.settingsTab = nil
                        model.showingQuiz = true
                    }
                }
            }
            SituationSettings()
        }
        .formStyle(.grouped)
    }
}

struct MemorySettings: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                HStack(alignment: .top, spacing: 8) {
                    TextField("", text: $draft, prompt: Text("Something to keep in mind, e.g. “I passed telc B1 in March 2021”"), axis: .vertical)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1...4)
                        .frame(maxWidth: .infinity)
                        .onSubmit(add)
                    Button("Remember", action: add).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Used with personal questions to pick the right rules and phrase answers. Never used to decide whether you qualify. Turn off “Use my situation” in the question bar to leave it out.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Remembered") {
                if model.settings.memories.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                }
                ForEach($model.settings.memories) { $note in
                    HStack {
                        TextField("", text: $note.text).textFieldStyle(.plain)
                        Button(role: .destructive) {
                            model.settings.memories.removeAll { $0.id == note.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Forget this")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func add() {
        model.remember(draft)
        draft = ""
    }
}

// MARK: Model

/// Choose the engine first (Apple's built-in model or a model server on this Mac), then the model.
struct ModelSettings: View {
    @Environment(AppModel.self) private var model

    enum Engine: String, CaseIterable, Identifiable {
        case apple, ollama, lmStudio, llamaCpp, other
        var id: Self { self }

        var title: String {
            switch self {
            case .apple: "Apple (built in)"
            case .ollama: "Ollama"
            case .lmStudio: "LM Studio"
            case .llamaCpp: "llama.cpp"
            case .other: "Other server"
            }
        }

        var summary: String {
            switch self {
            case .apple: "Apple's on-device model. Nothing to install, but small: in testing it often misread the law."
            case .ollama: "A free app that runs open models. Recommended: the app can download models for you."
            case .lmStudio: "A free app with a model browser. Start its local server, then pick a model here."
            case .llamaCpp: "For technical users running llama-server on this Mac."
            case .other: "Any OpenAI-compatible server running on this Mac."
            }
        }

        var kind: LocalServerProvider.Kind? {
            switch self {
            case .apple: nil
            case .ollama: .ollama
            case .lmStudio: .lmStudio
            case .llamaCpp: .llamaCpp
            case .other: .openAICompatible
            }
        }
    }

    @State private var engine: Engine = .apple
    @State private var address = ""
    @State private var models: [String] = []
    @State private var selectedModel = ""
    @State private var status: String?
    @State private var testing = false

    var body: some View {
        Form {
            Section {
                Picker("Engine", selection: $engine) {
                    ForEach(Engine.allCases) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.title)
                            Text(e.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(e)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .onChange(of: engine) { switchEngine() }
            } header: {
                Text("1. Choose an engine")
            } footer: {
                Text("In use now: \(model.providerName)").font(.caption).foregroundStyle(.secondary)
            }

            HardwareSummary()

            switch engine {
            case .apple:
                Section("2. Apple's model") {
                    if let reason = FoundationModelsProvider.unavailableReason {
                        Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    } else {
                        Label("Ready", systemImage: "checkmark.circle").foregroundStyle(.green)
                    }
                    LabeledContent("Time per answer", value: appleTime)
                    Text("Apple's model reads fewer law passages per answer, and in testing it sometimes blocked ordinary questions or contradicted the law it quoted. If this Mac can run a local model, use one.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            case .ollama:
                ModelAdvisorView()
            default:
                Section("2. Connect to \(engine.title)") {
                    TextField("Address", text: $address)
                    Text("Only addresses on this Mac (localhost or 127.0.0.1) are allowed.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Connect") { Task { await test() } }.disabled(testing)
                        if testing { ProgressView().controlSize(.small) }
                        if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
                    }
                    if !models.isEmpty {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(models, id: \.self) { Text($0).tag($0) }
                        }
                        .onChange(of: selectedModel) { applyLocal() }
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://ollama.com/library")!) { Label("Ollama model library", systemImage: "arrow.up.right.square") }
                Link(destination: URL(string: "https://lmstudio.ai/models")!) { Label("LM Studio model catalogue", systemImage: "arrow.up.right.square") }
                Link(destination: URL(string: "https://huggingface.co/models?library=gguf&language=de&sort=trending")!) {
                    Label("Hugging Face: models that support German (GGUF)", systemImage: "arrow.up.right.square")
                }
            } header: {
                Text("Find more models")
            } footer: {
                Text("Opens in your browser. Look for models that support German and your language and fit this Mac's memory; the list above shows what fits.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadCurrent)
    }

    private var appleTime: String {
        if let times = model.settings.answerTimes["Apple on-device model"], !times.isEmpty {
            return "measured: about \(Int((times.reduce(0, +) / Double(times.count)).rounded())) seconds"
        }
        return "about 20 to 60 seconds (not measured yet)"
    }

    private func loadCurrent() {
        switch model.settings.provider {
        case .apple:
            engine = .apple
        case let .localServer(k, url, m):
            engine = Engine.allCases.first { $0.kind == k } ?? .other
            address = url.absoluteString; selectedModel = m
            if engine != .ollama { Task { await test() } }
        }
    }

    private func switchEngine() {
        status = nil; models = []
        switch engine {
        case .apple:
            model.settings.provider = .apple
        case .ollama:
            // The Ollama list below sets the model when the user picks "Use".
            break
        default:
            if let kind = engine.kind {
                if case let .localServer(k, url, _) = model.settings.provider, k == kind { address = url.absoluteString }
                else { address = kind.defaultBaseURL.absoluteString }
            }
        }
    }

    private func test() async {
        guard let kind = engine.kind else { return }
        testing = true; defer { testing = false }
        guard let url = URL(string: address) else { status = "That isn't a valid address."; return }
        do {
            models = try await LocalServerProvider.availableModels(kind: kind, baseURL: url)
            status = models.isEmpty ? "Connected, but the server has no models." : "Connected · \(models.count) models"
            if !models.contains(selectedModel) { selectedModel = models.first ?? "" }
            applyLocal()
        } catch {
            models = []
            status = "Couldn't connect. Is \(engine.title) running, with its server started? (\(error.localizedDescription))"
        }
    }

    private func applyLocal() {
        guard let kind = engine.kind, let url = URL(string: address), LocalServerProvider.isLocal(url) else {
            status = "Only addresses on this Mac are allowed."; return
        }
        guard !selectedModel.isEmpty else { return }
        model.settings.provider = .localServer(kind: kind, baseURL: url, model: selectedModel)
    }
}

// MARK: Language and situation (also used by onboarding)

struct LanguageSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section("Language") {
            Picker("The app answers in", selection: $model.settings.preferences.languageCode) {
                ForEach(languageChoices, id: \.self) { code in
                    Text(languageName(code)).tag(code)
                }
            }
            if let warning = model.languageWarning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
        }

        Section("Explanations") {
            StylePicker(style: $model.settings.preferences.style)
        }

        Section {
            Picker("Official German text of the law", selection: $model.settings.preferences.alwaysShowGerman) {
                Text("Show it next to every translation").tag(true)
                Text("Show it only when I ask").tag(false)
            }
            .pickerStyle(.radioGroup)
        } header: {
            Text("Quotes from the law")
        } footer: {
            Text("Answers quote the law in German, the only legally binding version, and translate the quote into your language. Either way, every quote is checked word for word.")
                .font(.caption).foregroundStyle(.secondary)
        }

    }
}

/// The three explanation styles, as cards. Used in Settings and in the guided setup.
struct StylePicker: View {
    @Binding var style: AnswerPreferences.Style
    var onPick: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            ForEach(AnswerPreferences.Style.allCases, id: \.self) { option in
                ChoiceButton(title: option.title, subtitle: option.subtitle, selected: style == option) {
                    style = option
                    onPick()
                }
            }
        }
    }
}

struct SituationSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let situation = model.settings.situation
        Section("Name and avatar") {
            TextField("What should I call you?", text: $model.settings.preferredName, prompt: Text("Your name or a nickname"))
            LabeledContent("Avatar") { CatPicker(fur: $model.settings.avatar) }
        }
        Section {
            CountryField(code: $model.settings.situation.countryCode)
            if situation.countryCode == nil {
                Picker("Nationality", selection: $model.settings.situation.nationalityGroup) {
                    Text("Not set").tag(Situation.NationalityGroup?.none)
                    Text("EU, EEA or Swiss").tag(Situation.NationalityGroup?.some(.euEEASwiss))
                    Text("Another country").tag(Situation.NationalityGroup?.some(.nonEU))
                }
            }

            Picker("Current status", selection: $model.settings.situation.status) {
                Text("Not set").tag(Situation.Status?.none)
                ForEach(Situation.Status.allCases, id: \.self) { status in
                    Text("\(status.german) (\(status.english))").tag(Situation.Status?.some(status))
                }
            }

            if situation.status?.hasPurpose == true {
                Picker("Purpose on your permit", selection: $model.settings.situation.purpose) {
                    Text("Not set / don't know").tag(Situation.Purpose?.none)
                    ForEach(Situation.Purpose.allCases, id: \.self) { purpose in
                        Text("\(purpose.german) (\(purpose.english))").tag(Situation.Purpose?.some(purpose))
                    }
                }
                .help("The Aufenthaltszweck: the reason your permit was issued, usually printed on the card or its supplementary sheet (Zusatzblatt), e.g. § 18b AufenthG. It isn't necessarily what you do now.")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("First arrived in Germany")
                    Spacer()
                    if model.settings.situation.firstArrival != nil {
                        Button("Clear") { model.settings.situation.firstArrival = nil }.buttonStyle(.link)
                    }
                }
                MonthYearPicker(date: $model.settings.situation.firstArrival, compact: true)
            }
        } header: {
            Text("Your situation (all optional)")
        }

        Section("Applications you've made that haven't been decided yet") {
            ForEach(Situation.Application.allCases, id: \.self) { application in
                Toggle(isOn: Binding(
                    get: { model.settings.situation.pendingApplications.contains(application) },
                    set: {
                        if $0 { model.settings.situation.pendingApplications.insert(application) }
                        else { model.settings.situation.pendingApplications.remove(application) }
                    }
                )) {
                    ApplicationLabel(application: application)
                }
            }
        }

        Section {
            ForEach(Situation.Goal.allCases, id: \.self) { goal in
                Toggle(goalName(goal), isOn: Binding(
                    get: { model.settings.situation.goals.contains(goal) },
                    set: { if $0 { model.settings.situation.goals.insert(goal) } else { model.settings.situation.goals.remove(goal) } }
                ))
            }
        } header: {
            Text("What you're trying to achieve")
        } footer: {
            Text("Only used to find the right rules and phrase explanations. It never decides whether you qualify. Stored only on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func goalName(_ goal: Situation.Goal) -> String { "\(goal.german) (\(goal.english))" }
}

/// Nationality with suggestions as you type, in English and German.
struct CountryField: View {
    @Binding var code: String?
    @State private var text = ""

    struct Country: Hashable {
        let code: String
        let english: String
        let german: String
        var label: String { english == german ? english : "\(english) (\(german))" }
    }

    static let all: [Country] = Locale.Region.isoRegions
        .filter { $0.subRegions.isEmpty && $0.identifier.count == 2 && $0.identifier != "DE" }
        .compactMap { region in
            let id = region.identifier
            guard let en = Locale(identifier: "en").localizedString(forRegionCode: id),
                  let de = Locale(identifier: "de").localizedString(forRegionCode: id) else { return nil }
            return Country(code: id, english: en, german: de)
        }
        .sorted { $0.english.localizedStandardCompare($1.english) == .orderedAscending }

    private var matches: [Country] {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return Self.all.filter {
            $0.english.localizedStandardContains(q) || $0.german.localizedStandardContains(q) || $0.code.caseInsensitiveCompare(q) == .orderedSame
        }.prefix(12).map { $0 }
    }

    var body: some View {
        HStack {
            TextField("Nationality", text: $text, prompt: Text("Start typing a country"))
                .multilineTextAlignment(.leading)
                .textInputSuggestions {
                    ForEach(matches, id: \.self) { country in
                        Text(country.label).textInputCompletion(country.label)
                    }
                }
                .onChange(of: text) { resolve() }
            if code != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Recognised")
            }
        }
        .onAppear {
            if let code, let country = Self.all.first(where: { $0.code == code }) { text = country.label }
        }
    }

    private func resolve() {
        let q = text.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { code = nil; return }
        let exact = Self.all.first {
            $0.label.caseInsensitiveCompare(q) == .orderedSame || $0.english.caseInsensitiveCompare(q) == .orderedSame
                || $0.german.caseInsensitiveCompare(q) == .orderedSame
        }
        code = exact?.code
    }
}

/// Month and year of first arrival in Germany.
struct ArrivalField: View {
    @Binding var date: Date?

    var body: some View {
        LabeledContent("First arrived in Germany") {
            HStack {
                if let date {
                    DatePicker("", selection: Binding(get: { date }, set: { self.date = $0 }),
                               in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                    Button("Clear") { self.date = nil }.buttonStyle(.link)
                } else {
                    Button("Set date") {
                        date = Calendar.current.date(byAdding: .year, value: -1, to: Date())
                    }
                }
            }
        }
        .help("Used to work out how long you've been in Germany, so it stays current.")
    }
}

// MARK: Laws

struct LawSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Law collection") {
                if let index = model.index {
                    LabeledContent("Last checked against the official site", value: index.checkedAt?.lawDate ?? "Unknown")
                    ForEach(index.lawDates, id: \.law) { entry in
                        LabeledContent(LawSource.v1.first { $0.law == entry.law }.map { "\($0.title) (\(entry.law))" } ?? entry.law,
                                       value: "version of \(entry.asOf.lawDate)")
                    }
                    Text("Each law has its own date: the last time it was changed. A law that hasn't changed keeps an older date and is still current.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(model.loadError ?? "Loading…")
                }
            }
            Section {
                HStack {
                    Button("Update laws") { Task { await model.updateLaws() } }
                        .disabled(model.isUpdatingLaws)
                    if model.isUpdatingLaws { ProgressView().controlSize(.small) }
                    if let message = model.lawUpdateMessage { Text(message).font(.caption) }
                }
            } footer: {
                Text("Downloads the current official texts from gesetze-im-internet.de. This is the only time the app connects to the internet, and it sends nothing about you.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Privacy

struct PrivacySettings: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingDelete = false
    @State private var exporting = false
    @State private var fileVault: Bool?? = .none
    @State private var confirmingDeleteChats = false

    var body: some View {
        Form {
            Section {
                PrivacyPromise()
            }

            Section {
                if model.networkLog.isEmpty {
                    Text("No connections yet this session.").foregroundStyle(.secondary)
                }
                ForEach(model.networkLog.prefix(30)) { entry in
                    HStack {
                        Image(systemName: entry.allowed ? "checkmark.shield" : "xmark.shield.fill")
                            .foregroundStyle(entry.allowed ? .green : .red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.purpose)
                            Text("\(entry.host) · \(entry.date.formatted(date: .omitted, time: .standard))\(entry.allowed ? "" : " · blocked")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Every connection this session")
            } footer: {
                Text("Recorded by the app itself as it connects. Only the address is recorded, never what was sent. For an outside check, run Little Snitch or LuLu, or turn off Wi-Fi: everything except “Update laws” keeps working.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Keep my chats on this Mac", isOn: Binding(
                    get: { model.settings.keepChats },
                    set: { model.settings.keepChats = $0; model.saveChats() }
                ))
                Button("Delete all chats…", role: .destructive) { confirmingDeleteChats = true }
            } header: {
                Text("Chats")
            } footer: {
                Text("Kept chats are stored in the app's folder, protected by macOS. Ghost chats are never kept. Turning this off deletes the saved chats when you next quit.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Where your data is") {
                LabeledContent("Folder") {
                    Button("Show in Finder") {
                        try? FileManager.default.createDirectory(at: AppModel.supportDirectory, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([AppModel.supportDirectory])
                    }
                }
                Text(AppModel.supportDirectory.path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                switch fileVault {
                case .some(.some(true)):
                    Label("FileVault is on: this Mac's disk, including your documents, is encrypted.", systemImage: "lock.fill")
                        .foregroundStyle(.green)
                case .some(.some(false)):
                    Label("FileVault is off. Anyone with your Mac could read your documents. Turn it on in System Settings → Privacy & Security → FileVault.", systemImage: "lock.open")
                        .foregroundStyle(Theme.amber)
                default:
                    Text("Checking disk encryption…").foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Export my settings and document list…") { exporting = true }
                Button("Delete everything…", role: .destructive) { confirmingDelete = true }
            } footer: {
                Text("Delete everything removes your situation, memory, documents, downloaded laws and this session's questions.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { fileVault = .some(await Task.detached { AppModel.fileVaultIsOn() }.value) }
        .fileExporter(isPresented: $exporting, document: JSONFile(data: (try? model.exportData()) ?? Data()),
                      contentType: .json, defaultFilename: "Not a Lawyer data") { _ in }
        .confirmationDialog("Delete all chats? This can't be undone.", isPresented: $confirmingDeleteChats) {
            Button("Delete all chats", role: .destructive) { model.deleteAllChats() }
        }
        .confirmationDialog("Delete your situation, memory, documents, downloaded laws and all chats?",
                            isPresented: $confirmingDelete) {
            Button("Delete everything", role: .destructive) { model.deleteEverything() }
        }
    }
}

/// What stays on this Mac, in plain words. Shown in Settings and in the toolbar popover.
struct PrivacyPromise: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Everything stays on this Mac", systemImage: "lock.shield.fill")
                .font(.headline).foregroundStyle(.green)
            Group {
                Label("Your questions go only to the model on this Mac: \(model.providerName). Apple's on-device model never uses Private Cloud Compute here.", systemImage: "cpu")
                Label("Your situation, memory, documents and kept chats are stored in this app's folder and read only on this Mac. Documents are never given to the model.", systemImage: "folder")
                Label("The app can connect to two places only: this Mac, and gesetze-im-internet.de when you choose “Update laws”. Anything else is blocked before it starts.", systemImage: "network.badge.shield.half.filled")
                Label("Speaking a question is recognised on this Mac only; the app never lets your voice go to Apple's servers.", systemImage: "mic")
                Label("No account, no analytics, no crash reports.", systemImage: "eye.slash")
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The privacy summary and the live connection list, opened from the lock in the profile corner.
struct PrivacyPopover: View {
    @Environment(AppModel.self) private var model
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PrivacyPromise()
            Divider()
            Text("Connections this session").font(.subheadline.weight(.semibold))
            if model.networkLog.isEmpty { Text("None yet.").foregroundStyle(.secondary) }
            ForEach(Array(Dictionary(grouping: model.networkLog, by: \.host).sorted { $0.key < $1.key }), id: \.key) { host, entries in
                HStack {
                    Image(systemName: entries.allSatisfy(\.allowed) ? "checkmark.shield" : "xmark.shield.fill")
                        .foregroundStyle(entries.allSatisfy(\.allowed) ? .green : .red)
                    Text(host).font(.callout.monospaced())
                    Spacer()
                    Text("\(entries.count)×").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Button("Open Privacy Settings") { close(); model.settingsTab = .privacy }
        }
        .padding(18)
        .frame(width: 400)
    }
}

struct JSONFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}


/// An application type with the section of the law that governs it, linked to the official text.
struct ApplicationLabel: View {
    let application: Situation.Application

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(application.german) (\(application.english))")
            if let source = LawSource.v1.first(where: { $0.law == application.ref.law }) {
                Link(application.ref.label, destination: source.sectionURL(application.ref.section))
                    .font(.caption)
                    .help("Open the official text on gesetze-im-internet.de")
            }
        }
    }
}
