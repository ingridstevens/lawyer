import NotALawyerCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.settings.acknowledgedDisclaimer {
                RootView()
                    .sheet(item: $model.settingsTab) { _ in SettingsPanel() }
                    .sheet(isPresented: Binding(
                        get: { model.showingQuiz || !model.settings.finishedOnboarding },
                        set: { if !$0 { model.showingQuiz = false } }
                    )) { SituationQuiz() }
            } else {
                FirstLaunchView()
            }
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.stamp)
    }
}

// MARK: Root

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            switch model.sidebarSelection {
            case .chat: ConversationView()
            case .documents: DocumentsView()
            case .plan(let id):
                if let plan = Plan.all.first(where: { $0.id == id }) { PlanView(plan: plan) }
            case .helpResources: HelpResourcesView()
            case .prepareContact: PrepareContactView()
            }
        }
    }
}

struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: Binding<SidebarItem?>(
            get: { model.sidebarSelection },
            set: { if let item = $0 { model.sidebarSelection = item } }
        )) {
            HStack(spacing: 8) {
                Button { model.newChat() } label: {
                    Label("New chat", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.stamp.opacity(0.1)))
                        .foregroundStyle(Theme.stamp)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("New chat (⌘N)")
                Button { model.newChat(ghost: true) } label: {
                    GhostIcon(size: 16).foregroundStyle(.secondary)
                        .frame(width: 32, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("New ghost chat: leaves out your situation, memory and documents (⇧⌘N)")
                .accessibilityLabel("New ghost chat")
            }
            .listRowSeparator(.hidden)
            .padding(.bottom, 4)

            Section("Chats") {
                ForEach(model.chats.reversed()) { chat in
                    ChatRow(chat: chat).tag(SidebarItem.chat(chat.id))
                }
            }

            Section("Your things") {
                Label {
                    HStack {
                        Text("My documents")
                        Spacer()
                        if !model.documents.records.isEmpty {
                            Text("\(model.documents.records.count)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                } icon: { Image(systemName: "folder") }
                .tag(SidebarItem.documents)
            }

            Section("Get help") {
                Label("Free help near you", systemImage: "person.2.wave.2").tag(SidebarItem.helpResources)
                Label("Prepare a call, email or visit", systemImage: "square.and.pencil").tag(SidebarItem.prepareContact)
            }

            Section("Plans") {
                ForEach(model.visiblePlans) { plan in
                    let done = plan.steps.filter { model.isDone($0, in: plan) }.count
                    Label {
                        HStack {
                            Text(plan.title).lineLimit(1)
                            Spacer()
                            Text("\(done)/\(plan.steps.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    } icon: { Image(systemName: "checklist") }
                    .tag(SidebarItem.plan(plan.id))
                }
            }
        }
        .safeAreaInset(edge: .bottom) { SituationSummaryButton().padding(12) }
    }

    @ViewBuilder static func statusDot(_ state: Exchange.State) -> some View {
        switch state {
        case .thinking: ProgressView().controlSize(.mini)
        case .answered(let a) where a.refused || a.route != .law: Circle().fill(.secondary).frame(width: 7, height: 7)
        case .answered: Circle().fill(Theme.stamp).frame(width: 7, height: 7)
        case .failed: Circle().fill(.red).frame(width: 7, height: 7)
        }
    }
}

struct ChatRow: View {
    @Environment(AppModel.self) private var model
    let chat: Chat
    @State private var renaming = false
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 8) {
            if chat.exchanges.contains(where: { if case .thinking = $0.state { true } else { false } }) {
                ProgressView().controlSize(.mini).frame(width: 14)
            } else if chat.ghost {
                GhostIcon(size: 14).foregroundStyle(.secondary).help("Ghost chat")
            } else if let last = chat.exchanges.last {
                Sidebar.statusDot(last.state).frame(width: 14)
            } else {
                Image(systemName: "text.bubble").foregroundStyle(.secondary).frame(width: 14)
            }
            Text(chat.title).lineLimit(1)
            Spacer()
        }
        .contextMenu {
            Button("Rename…") { draft = chat.title; renaming = true }
            if chat.exchanges.isEmpty && !chat.ghost {
                Button("Make This a Ghost Chat") { model.setGhost(true, for: chat.id) }
            }
            Divider()
            Button("Delete Chat", role: .destructive) { model.deleteChat(chat.id) }
        }
        .alert("Rename chat", isPresented: $renaming) {
            TextField("Name", text: $draft)
            Button("Rename") { model.renameChat(chat.id, to: draft) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Shows what the app knows about the user, one click from editing it.
/// The user's corner: who they are, their situation, the model and privacy. Everything that
/// applies to the whole app lives here, not in a chat's toolbar.
struct SituationSummaryButton: View {
    @Environment(AppModel.self) private var model
    @State private var showingPrivacy = false

    var body: some View {
        HStack(spacing: 10) {
            Button { model.settingsTab = .situation } label: {
                HStack(spacing: 10) {
                    CatAvatar(fur: model.settings.avatar, size: 32)
                    Text(model.settings.preferredName.isEmpty ? "You" : model.settings.preferredName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Your situation, settings and privacy (⌘,)")

            Button { showingPrivacy.toggle() } label: {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Everything stays on this Mac. Click to see every connection.")
            .popover(isPresented: $showingPrivacy, arrowEdge: .top) { PrivacyPopover(close: { showingPrivacy = false }) }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    /// e.g. "Niederlassungserlaubnis · goal: Einbürgerung"
    private var situationLine: String {
        let s = model.settings.situation
        var parts: [String] = []
        if let status = s.status { parts.append(status.german) }
        if let goal = Situation.Goal.allCases.first(where: { s.goals.contains($0) }) { parts.append("goal: \(goal.german)") }
        return parts.isEmpty ? "Situation not set up" : parts.joined(separator: " · ")
    }
}

// MARK: First launch

/// Says clearly what the app is and isn't. Acknowledged once (spec §4).
struct FirstLaunchView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                MarginRow {
                    Text("§").font(Theme.margin(96)).foregroundStyle(Theme.stamp).accessibilityHidden(true)
                } content: {
                    VStack(alignment: .leading, spacing: 14) {
                        Headline(text: "Not a Lawyer explains German residency law. It doesn't decide your case.")
                        Text("Ask in your own language. Every answer quotes the official German text it's based on, with the date of that text.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                MarginRow {
                    Text("Does").font(.headline).foregroundStyle(.secondary)
                } content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Finds the rules that fit your question and lists their conditions, so you can check them against your situation.")
                        Text("Shows the exact words of the law, highlighted in the official paragraph.")
                        Text("Runs entirely on this Mac. Your questions, details and documents never leave it.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                MarginRow {
                    Text("Doesn't").font(.headline).foregroundStyle(.secondary)
                } content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tell you whether you qualify. Only the authority decides that.")
                        Text("Replace advice. The explanations come from a small language model and can be wrong or incomplete. Translations are machine translations; the German text is the law.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                MarginRow {
                    EmptyView()
                } content: {
                    VStack(alignment: .leading, spacing: 24) {
                        WhereToAskView()
                        Button {
                            model.settings.acknowledgedDisclaimer = true
                        } label: {
                            Text("I understand").padding(.horizontal, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.extraLarge)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .frame(maxWidth: Theme.pageWidth)
            .padding(.vertical, 56)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .background(PageBackground())
    }
}

// MARK: Conversation

struct ConversationView: View {
    @Environment(AppModel.self) private var model
    @State private var question = ""
    @FocusState private var inputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var speech = SpeechInput()
    /// Text typed before dictation started; speech is added after it.
    @State private var typedBeforeSpeech = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        banners
                        ChatContextBar().padding(.top, 14)
                        if model.exchanges.isEmpty {
                            EmptyStateView(ask: model.ask)
                        }
                        ForEach(model.exchanges) { exchange in
                            ExchangeView(exchange: exchange)
                                .id(exchange.id)
                                .padding(.top, 40)
                            if exchange.id != model.exchanges.last?.id {
                                Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 40)
                            }
                        }
                        Color.clear.frame(height: 130)
                    }
                    .frame(maxWidth: Theme.pageWidth)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: model.exchanges.count) {
                    guard let last = model.exchanges.last else { return }
                    withAnimation(.smooth) { proxy.scrollTo(last.id, anchor: .top) }
                }
                .onChange(of: model.scrollTarget) {
                    guard let target = model.scrollTarget else { return }
                    withAnimation(.smooth) { proxy.scrollTo(target, anchor: .top) }
                    model.scrollTarget = nil
                }
            }
            inputBar
        }
        // The ghost backdrop stays in the chat area; it mustn't run under the sidebar.
        .background { if model.currentChat.ghost { GhostBackground() } else { PageBackground() } }
        .backgroundExtensionEffect(isEnabled: false)
        .environment(\.colorScheme, model.currentChat.ghost ? .dark : colorScheme)
        .navigationTitle(model.currentChat.title)
        .navigationSubtitle(model.currentChat.ghost ? "Ghost chat · \(model.providerName)" : model.providerName)
        .onAppear { inputFocused = true }
    }

    @ViewBuilder private var banners: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = model.loadError {
                Banner(text: "The laws couldn't be loaded: \(error) Update them in Settings → Laws.", tint: .red)
            }
            if model.lawsAreStale, let checked = model.index?.checkedAt {
                Banner(text: "The laws were last checked against the official site on \(checked.lawDate). They may have changed since. Update them in Settings → Laws.", tint: Theme.amber)
            }
            if let warning = model.languageWarning {
                Banner(text: warning, tint: Theme.amber)
            }
            if model.currentChat.ghost && !model.exchanges.isEmpty {
                HStack(spacing: 8) {
                    GhostIcon(size: 16)
                    Text("Ghost chat: your situation, memory and documents aren't used here.")
                }
                .font(.callout).foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
            } else if !model.currentChat.ghost && model.settings.situation.countryCode == "TR" {
                Banner(text: "Turkish citizens can have extra rights under the EU–Turkey association agreement (ARB 1/80), for example for work and residence. This app doesn't cover them yet. Ask a free Migrationsberatung or a migration lawyer about them.", tint: Theme.stamp)
            }
        }
        .padding(.top, 20)
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if case .unavailable(let message) = speech.state {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mic.slash").foregroundStyle(Theme.amber)
                    Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { speech.dismissMessage() } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                }
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .frame(maxWidth: Theme.pageWidth)
            }
            if speech.isListening {
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                        .phaseAnimator([0.3, 1.0]) { view, phase in view.opacity(phase) }
                    Text("Listening, on this Mac only. Pause or click the microphone to stop.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            inputField
        }
        .onAppear {
            speech.onText = { text in
                question = typedBeforeSpeech.isEmpty ? text : typedBeforeSpeech + " " + text
            }
        }
        .onDisappear { speech.stop() }
    }

    private var inputField: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(speech.isListening ? "Listening…" : "Ask what the law says…", text: $question, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3)
                .lineLimit(1...6)
                .focused($inputFocused)
                .onSubmit(send)
                .accessibilityLabel("Your question")
            Button {
                if !speech.isListening { typedBeforeSpeech = question.trimmingCharacters(in: .whitespaces) }
                speech.toggle(languageCode: model.settings.preferences.languageCode)
            } label: {
                Image(systemName: speech.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(speech.isListening ? .white : .secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(speech.isListening ? Color.red : .clear))
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .help(speech.isListening ? "Stop listening" : "Speak your question (⇧⌘D). Recognised on this Mac only.")
            .accessibilityLabel(speech.isListening ? "Stop listening" : "Speak your question")
            SendButton(enabled: canSend, action: send)
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .frame(maxWidth: Theme.gutter + 18 + Theme.column)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private var canSend: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send() {
        guard canSend else { return }
        speech.stop()
        model.ask(question)
        question = ""
    }
}

struct SendButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(enabled ? Theme.stamp : Color.secondary.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Ask")
    }
}

/// A warning line with a coloured rule on the left. Says what's wrong and what to do.
struct Banner: View {
    let text: String
    let tint: Color

    var body: some View {
        MarginRow {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(tint).accessibilityHidden(true)
        } content: {
            Text(text)
                .font(.callout)
                .padding(.leading, 12)
                .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The start of a new chat: a greeting, questions that fit the user's goals, their plan, and
/// the ghost switch. A ghost chat starts dark and says plainly what's left out.
struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    let ask: (String) -> Void

    var body: some View {
        let ghost = model.currentChat.ghost
        VStack(alignment: .leading, spacing: 34) {
            HStack(alignment: .top) {
                Spacer()
                if ghost {
                    HStack(spacing: 6) { GhostIcon(size: 15); Text("Ghost chat") }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().stroke(.white.opacity(0.3)))
                        .accessibilityLabel("This is a ghost chat")
                } else {
                    // One way only: a chat can become a ghost chat, never the other way round.
                    Button { withAnimation(.smooth) { model.setGhost(true, for: model.currentChatID) } } label: {
                        HStack(spacing: 6) { GhostIcon(size: 15); Text("Start ghost chat") }
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .help("Leaves out your situation, memory and documents for this whole chat. It can't be turned off again.")
                }
            }

            if ghost {
                VStack(alignment: .leading, spacing: 14) {
                    GhostIcon(size: 64).foregroundStyle(.white)
                    Text("Ghost chat").font(Theme.serif(.largeTitle, weight: .semibold)).foregroundStyle(.white)
                    Text("Nothing about you goes into this chat: not your situation, not your memory, not your documents. Questions are answered as if anyone had asked them. A ghost chat is never saved; when you close the app, it's gone.")
                        .font(.title3).foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        CatAvatar(fur: model.settings.avatar, size: 56)
                        Headline(text: model.settings.preferredName.isEmpty ? "Hello" : "Hello, \(model.settings.preferredName)",
                                 size: 34)
                    }
                    Text("What would you like to understand about German residency law today?")
                        .font(.title3).foregroundStyle(.secondary)
                }

                if let plan = model.visiblePlans.first, !model.settings.situation.goals.isEmpty {
                    let done = plan.steps.filter { model.isDone($0, in: plan) }.count
                    Button { model.sidebarSelection = .plan(plan.id) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                                Circle().trim(from: 0, to: CGFloat(done) / CGFloat(max(plan.steps.count, 1)))
                                    .stroke(Theme.stamp, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(done)/\(plan.steps.count)").font(.caption.weight(.semibold)).monospacedDigit()
                            }
                            .frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Continue your plan").font(.caption).foregroundStyle(.secondary)
                                Text(plan.german).font(.headline)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.stamp.opacity(0.07)))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(ghost ? "Ask anything about residency or citizenship law"
                     : model.currentChat.goal.map { "Questions about \($0.german)" } ?? "Questions people often ask")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ghost ? .white.opacity(0.7) : .secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(suggestions, id: \.question) { s in
                        Button { ask(s.question) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: s.icon).font(.title3).foregroundStyle(ghost ? .white : Theme.stamp)
                                Text(s.question)
                                    .font(.callout)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundStyle(ghost ? .white : Theme.ink)
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(ghost ? Color.white.opacity(0.08) : Color.secondary.opacity(0.07)))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let index = model.index {
                Text("Quotes from the Aufenthaltsgesetz, Staatsangehörigkeitsgesetz, Beschäftigungsverordnung, Aufenthaltsverordnung and Freizügigkeitsgesetz/EU, last checked \((index.checkedAt ?? index.asOf).lawDate).")
                    .font(.caption)
                    .foregroundStyle(ghost ? .white.opacity(0.5) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 20)
    }

    /// Questions that fit the user's goals first, then common ones. Ghost chats get only general ones.
    /// Starting questions for the chat's goal, in plain words; general ones otherwise.
    private var suggestions: [(icon: String, question: String)] {
        let goal = model.currentChat.ghost ? nil : model.currentChat.goal
        let byGoal: [Situation.Goal: [(String, String)]] = [
            .citizenship: [("checklist", "What do I need to become German?"),
                           ("calendar", "How many years do I have to live in Germany first?"),
                           ("person.2", "Can I keep my current passport if I become German?"),
                           ("text.book.closed", "What German level and which test do I need?")],
            .permanentResidence: [("checklist", "What do I need for permanent residence?"),
                                  ("graduationcap", "Do my years as a student count towards it?"),
                                  ("briefcase", "Is there a faster route for skilled workers or Blue Card holders?"),
                                  ("arrow.left.arrow.right", "What's the difference between a Niederlassungserlaubnis and a Daueraufenthalt-EU?")],
            .extend: [("calendar.badge.clock", "When should I apply to extend my residence permit?"),
                      ("doc.text", "What documents do I need to extend it?"),
                      ("hourglass", "What happens if my permit expires before they decide?"),
                      ("briefcase", "Can I extend it if I've lost my job?")],
            .changePurpose: [("arrow.triangle.swap", "Can I switch from a student permit to a work permit?"),
                             ("briefcase", "Can I change the purpose of my residence permit?"),
                             ("magnifyingglass", "Can I stay to look for a job after my degree?"),
                             ("doc.text", "What do I need to apply for the change?")],
            .bringFamily: [("figure.2.and.child.holdinghands", "Can my spouse and children join me in Germany?"),
                           ("house", "How much living space and income do I need?"),
                           ("character.book.closed", "Does my spouse need to speak German first?"),
                           ("briefcase", "Can my spouse work once they're here?")],
            .changeJob: [("briefcase", "Can I change my employer with my residence permit?"),
                         ("bell", "Do I have to tell the Ausländerbehörde if I change jobs?"),
                         ("exclamationmark.triangle", "What happens to my permit if I lose my job?"),
                         ("person.badge.plus", "Can I work freelance alongside my job?")],
            .liveAbroad: [("airplane", "How long can I leave Germany without losing my residence permit?"),
                          ("calendar", "Does time abroad count against becoming German later?"),
                          ("doc.text", "How do I ask the Ausländerbehörde for a longer period abroad?"),
                          ("house", "Does a Niederlassungserlaubnis make long stays abroad easier?")],
        ]
        let general: [(String, String)] = [
            ("house", "When can I get permanent residence?"),
            ("flag", "What do I need to become German?"),
            ("figure.2.and.child.holdinghands", "Can my family join me in Germany?"),
            ("airplane", "How long can I stay abroad without losing my permit?"),
        ]
        return (goal.flatMap { byGoal[$0] } ?? general).map { (icon: $0.0, question: $0.1) }
    }
}

/// Dark backdrop for ghost chats.
struct GhostBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.07, green: 0.07, blue: 0.11), Color(red: 0.12, green: 0.1, blue: 0.2)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: [.top, .bottom])
    }
}

// MARK: Exchanges

struct ExchangeView: View {
    @Environment(AppModel.self) private var model
    let exchange: Exchange
    @State private var editing = false
    @State private var draft = ""
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // The question, as a message from the user: right-aligned bubble with their cat.
            HStack(alignment: .bottom, spacing: 10) {
                Spacer(minLength: 120)
                if hovering && !editing {
                    Button { draft = exchange.question; editing = true } label: { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                        .help("Edit and ask again")
                        .accessibilityLabel("Edit question")
                }
                VStack(alignment: .trailing, spacing: 6) {
                    if editing {
                        VStack(alignment: .trailing, spacing: 10) {
                            TextField("Question", text: $draft, axis: .vertical)
                                .font(.title3)
                                .textFieldStyle(.plain)
                                .lineLimit(1...6)
                                .frame(minWidth: 320)
                                .onSubmit(save)
                            HStack {
                                Button("Cancel") { editing = false }.keyboardShortcut(.cancelAction)
                                Button("Ask again", action: save).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                            }
                        }
                        .padding(14)
                        .background(bubble)
                    } else {
                        Text(exchange.question)
                            .font(.title3)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(bubble)
                            .contextMenu {
                                Button("Edit and Ask Again") { draft = exchange.question; editing = true }
                                Button("Remember This") { model.remember(exchange.question) }
                                Button("Remove", role: .destructive) { model.remove(exchange.id) }
                            }
                    }
                    if !exchange.personal {
                        HStack(spacing: 5) {
                            GhostIcon(size: 11)
                            Text("Ghost: your situation and memory weren't used")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if exchange.personal {
                    CatAvatar(fur: model.settings.avatar, size: 30)
                } else {
                    GhostIcon(size: 24).foregroundStyle(.secondary).frame(width: 30)
                }
            }
            .onHover { hovering = $0 }

            switch exchange.state {
            case .thinking(let stage):
                ProgressLine(stage: stage, exchange: exchange)
            case .answered(let answer) where answer.route != .law:
                RoutedReply(route: answer.route)
            case .answered(let answer) where answer.refused:
                RefusalView(answer: answer, compactFooter: !isFirstAnswer)
            case .answered(let answer):
                AnswerView(answer: answer, compactFooter: !isFirstAnswer)
            case .failed(let message):
                MarginRow {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                } content: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message).fixedSize(horizontal: false, vertical: true)
                        Button("Try again with \(model.providerName)") { model.reask(exchange.id, as: exchange.question) }
                    }
                }
            }

            if case .answered = exchange.state {
                MarginRow { EmptyView() } content: {
                    HStack(spacing: 10) {
                        Text("Answered by \(exchange.modelName)\(exchange.seconds.map { " in \(Int($0.rounded())) seconds" } ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                        if exchange.modelName != model.providerName {
                            Button("Ask again with \(model.providerName)") { model.reask(exchange.id, as: exchange.question) }
                                .buttonStyle(.link).font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func save() {
        editing = false
        if draft != exchange.question { model.reask(exchange.id, as: draft) }
    }

    /// The full "where to ask" box shows once per chat; later answers get one line.
    private var isFirstAnswer: Bool { model.exchanges.first?.id == exchange.id }

    private var bubble: some View {
        UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 5, topTrailingRadius: 18)
            .fill(Theme.stamp.opacity(0.1))
    }
}

/// Replies for questions that aren't about the law. The app answers these itself, from what
/// it knows, without searching or asking the model.
struct RoutedReply: View {
    @Environment(AppModel.self) private var model
    let route: QuestionRoute

    var body: some View {
        MarginRow {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                switch route {
                case .aboutMe:
                    Text(model.settings.preferredName.isEmpty
                         ? "I only know what you've told me under Your situation and My documents. I don't know your name; you can tell me what to call you in Settings → Your situation."
                         : "You asked me to call you \(model.settings.preferredName). Apart from that, I only know what you've told me under Your situation and My documents.")
                        .font(.title3)
                    let description = model.settings.situation.promptDescription()
                    if description.isEmpty {
                        Text("You haven't set up your situation yet.").foregroundStyle(.secondary)
                    } else {
                        Text(description).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Text("\(model.documents.records.count) documents added.").foregroundStyle(.secondary)
                    HStack {
                        Button("Edit your situation") { model.settingsTab = .situation }
                        Button("Open My documents") { model.sidebarSelection = .documents }
                    }
                case .aboutApp:
                    Text("Not a Lawyer explains German residency and citizenship law, quoting the official text word for word. It covers the Aufenthaltsgesetz, Staatsangehörigkeitsgesetz, Beschäftigungsverordnung, Aufenthaltsverordnung and Freizügigkeitsgesetz/EU.")
                        .font(.title3)
                    Text("Everything runs on this Mac with \(model.providerName). It never decides whether you qualify for anything.")
                        .foregroundStyle(.secondary)
                case .other, .law:
                    Text("I can only answer questions about German residency, citizenship and work-permit law.")
                        .font(.title3)
                    Text("Try asking about a permit, a visa, settling permanently, becoming German or bringing your family.")
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var icon: String {
        switch route {
        case .aboutMe: "person.crop.circle"
        case .aboutApp: "info.circle"
        case .other, .law: "arrow.uturn.left.circle"
        }
    }
}

/// What's happening while the user waits: three steps, the current one live, and a bar
/// that fills over this model's usual answer time. Local models can take a few minutes.
struct ProgressLine: View {
    @Environment(AppModel.self) private var model
    let stage: AnswerStage
    let exchange: Exchange
    @State private var startedAt = Date()

    private var step: Int {
        switch stage {
        case .queued: -1
        case .searching: 0
        case .writing: 1
        case .checking: 2
        }
    }

    var body: some View {
        MarginRow {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    stepView(0, "Planning")
                    connector(done: step > 0)
                    stepView(1, "Reading the law")
                    connector(done: step > 1)
                    stepView(2, "Checking quotes")
                }
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(.default, value: detail)

                if stage != .queued {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    VStack(alignment: .leading, spacing: 6) {
                        if let typical {
                            ProgressView(value: min(elapsed / typical, 0.95))
                                .tint(Theme.stamp)
                                .frame(maxWidth: 360)
                        }
                        HStack(spacing: 10) {
                            Text(timeText(elapsed)).monospacedDigit()
                            Button(role: .cancel) { model.stop(exchange.id) } label: {
                                Label("Stop", systemImage: "stop.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Stop working on this question. Nothing is lost: you can ask it again.")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                // The clock starts when the question leaves the queue.
                .onAppear { startedAt = Date() }
                }

                if stage == .queued {
                    Label("Questions to the same model are answered one after another.", systemImage: "hourglass")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if exchange.modelName != model.providerName {
                    Text("You've switched to \(model.providerName). This question keeps going with \(exchange.modelName); ask it again to use the new model.")
                        .font(.caption).foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func stepView(_ index: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(index < step ? Theme.stamp : index == step ? Theme.stamp.opacity(0.15) : Color.secondary.opacity(0.12))
                    .frame(width: 20, height: 20)
                if index < step {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                } else if index == step {
                    Circle().fill(Theme.stamp).frame(width: 8, height: 8)
                        .phaseAnimator([0.4, 1.0]) { view, phase in view.opacity(phase) }
                }
            }
            Text(title)
                .font(.callout.weight(index == step ? .semibold : .regular))
                .foregroundStyle(index <= step ? Theme.ink : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(index < step ? "done" : index == step ? "in progress" : "to do")")
    }

    private func connector(done: Bool) -> some View {
        Rectangle().fill(done ? Theme.stamp : Color.secondary.opacity(0.25))
            .frame(width: 28, height: 2)
            .padding(.horizontal, 8)
    }

    private var typical: Double? {
        model.settings.answerTimes[exchange.modelName].map { $0.reduce(0, +) / Double($0.count) }
    }

    private func timeText(_ elapsed: Double) -> String {
        let s = Int(elapsed)
        guard let typical else { return "\(s) s" }
        let left = Int(typical - elapsed)
        return left > 5 ? "\(s) s · about \(left) s left (usual for \(exchange.modelName))" : "\(s) s · taking a little longer than usual"
    }

    private var detail: String {
        switch stage {
        case .queued:
            "Waiting: \(exchange.modelName) is still answering another question. This one starts as soon as it's done."
        case .searching:
            "Working out what kind of question this is and which words to look up in the law."
        case .writing(let sections):
            "\(exchange.modelName) is reading \(ListFormatter.localizedString(byJoining: Array(sections.prefix(4)))) and writing an explanation."
        case .checking:
            "Checking every quote word for word against the official text."
        }
    }
}

/// The chat's goal and notes, at the top of every chat. Every question in the chat is answered
/// with these in mind, so follow-ups keep their context.
struct ChatContextBar: View {
    @Environment(AppModel.self) private var model
    @State private var editingNotes = false
    @State private var draft = ""

    var body: some View {
        let chat = model.currentChat
        MarginRow {
            EmptyView()
        } content: {
            HStack(spacing: 10) {
                Menu {
                    Button("No particular goal") { model.setGoal(nil, for: chat.id) }
                    Divider()
                    ForEach(Situation.Goal.allCases, id: \.self) { goal in
                        Button("\(goal.german) (\(goal.english))") { model.setGoal(goal, for: chat.id) }
                    }
                } label: {
                    Label(chat.goal.map { "Goal: \($0.german)" } ?? "Choose a goal for this chat", systemImage: "target")
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .help("Every question in this chat is answered with this goal in mind.")

                Button { draft = chat.context; editingNotes = true } label: {
                    Label(chat.context.isEmpty ? "Add notes for this chat" : "Notes: \(chat.context)", systemImage: "note.text")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Facts that matter for this chat only, e.g. “I studied in Germany from 2018 to 2021”.")
                .popover(isPresented: $editingNotes, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes for this chat").font(.headline)
                        Text("Facts that matter for the questions in this chat. They're used with every question here, and stay on this Mac.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        TextField("", text: $draft, prompt: Text("e.g. I studied in Germany from 2018 to 2021, then started work as an engineer"), axis: .vertical)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...8)
                        HStack {
                            Spacer()
                            Button("Cancel") { editingNotes = false }
                            Button("Save") { model.setContext(draft, for: chat.id); editingNotes = false }
                                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(16)
                    .frame(width: 380)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
