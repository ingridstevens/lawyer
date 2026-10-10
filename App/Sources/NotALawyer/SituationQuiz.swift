import NotALawyerCore
import SwiftUI

/// Guided setup: one question per card, each answer choosing the next card, then a summary
/// that saves everything at once. Nothing is stored until "Save".
struct SituationQuiz: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Hashable {
        case language, name, eu, country, status, purpose, arrival, applications, goals, style, summary
    }

    @State private var draft = StoredSettings()
    @State private var path: [Step] = [.language]
    @State private var forward = true
    @State private var loaded = false

    private var step: Step { path.last ?? .language }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Theme.stamp)
                .padding(.horizontal, 28).padding(.top, 22)
                .accessibilityLabel("Setup progress")

            ZStack {
                card(for: step)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            HStack {
                if path.count > 1 {
                    Button("Back") { go(back: true) }.keyboardShortcut(.cancelAction)
                } else {
                    Button("Skip setup") { finish(save: false) }
                }
                Spacer()
                if step == .summary {
                    Button("Save") { finish(save: true) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                } else if !isChoiceStep {
                    Button("Continue") { advance() }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                } else {
                    Button("Skip this question") { advance() }
                }
            }
            .padding(20)
        }
        .frame(width: 620, height: 600)
        .background(Theme.sheet)
        .foregroundStyle(Theme.ink)
        .tint(Theme.stamp)
        .onAppear {
            guard !loaded else { return }
            draft = model.settings
            loaded = true
        }
    }

    // MARK: Cards

    @ViewBuilder private func card(for step: Step) -> some View {
        switch step {
        case .language:
            QuizCard(title: "Which language should this app use?",
                     hint: "Explanations will be in this language. Quotes from the law stay in the original German, with a translation.") {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                        ForEach(languageChoices, id: \.self) { code in
                            ChoiceButton(title: Locale(identifier: code).localizedString(forLanguageCode: code) ?? code,
                                         subtitle: Locale(identifier: "en").localizedString(forLanguageCode: code),
                                         selected: draft.preferences.languageCode == code) {
                                draft.preferences.languageCode = code; advance()
                            }
                        }
                    }
                }
            }
        case .name:
            QuizCard(title: "What should I call you?",
                     hint: "Optional. It's only shown in the app, never sent anywhere. Pick a cat while you're here.") {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Your name or a nickname", text: $draft.preferredName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .frame(maxWidth: 360)
                        .onSubmit(advance)
                    CatPicker(fur: $draft.avatar)
                }
            }
        case .eu:
            QuizCard(title: "Are you a citizen of an EU country, Iceland, Liechtenstein, Norway or Switzerland?",
                     hint: "EU citizens and their families mostly follow a different law, the Freizügigkeitsgesetz/EU.") {
                VStack(spacing: 10) {
                    ChoiceButton(title: "Yes", selected: draft.situation.nationalityGroup == .euEEASwiss) {
                        draft.situation.nationalityGroup = .euEEASwiss
                        draft.situation.status = .euFreedomOfMovement
                        draft.situation.purpose = nil
                        advance()
                    }
                    ChoiceButton(title: "No", selected: draft.situation.nationalityGroup == .nonEU) {
                        draft.situation.nationalityGroup = .nonEU
                        if draft.situation.status == .euFreedomOfMovement { draft.situation.status = nil }
                        advance()
                    }
                    ChoiceButton(title: "I'd rather not say", selected: false) {
                        draft.situation.nationalityGroup = nil; advance()
                    }
                }
            }
        case .country:
            QuizCard(title: "Which country's passport do you have?",
                     hint: "Optional. A few rules depend on nationality. If you have more than one, pick the one you'd use for your residence.") {
                CountryField(code: $draft.situation.countryCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .frame(maxWidth: 420, alignment: .leading)
            }
        case .status:
            QuizCard(title: "What does your residence document say?",
                     hint: "Look at the line “Art des Titels” on your card, or the heading of the paper you were given.") {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Situation.Status.allCases.filter { $0 != .euFreedomOfMovement }, id: \.self) { status in
                            ChoiceButton(title: status.german, subtitle: status.english, selected: draft.situation.status == status) {
                                draft.situation.status = status
                                if !status.hasPurpose { draft.situation.purpose = nil }
                                advance()
                            }
                        }
                        ChoiceButton(title: "I'm not sure", subtitle: "You can add it later, or add a photo of your card in My documents",
                                     selected: false) { draft.situation.status = nil; advance() }
                    }
                }
            }
        case .purpose:
            QuizCard(title: "What purpose is written on your permit?",
                     hint: "This is the Aufenthaltszweck: the reason the permit was issued, not what you do today. It's on the supplementary sheet (Zusatzblatt) as a section number. For example, § 18a to § 21 are work, § 16 to § 17 are study or training, § 27 to § 36 are family.") {
                VStack(spacing: 8) {
                    ForEach(Situation.Purpose.allCases, id: \.self) { purpose in
                        ChoiceButton(title: purpose.german, subtitle: purpose.english, selected: draft.situation.purpose == purpose) {
                            draft.situation.purpose = purpose; advance()
                        }
                    }
                    ChoiceButton(title: "I don't know", selected: false) { draft.situation.purpose = nil; advance() }
                }
            }
        case .arrival:
            QuizCard(title: "When did you first come to live in Germany?",
                     hint: "Month and year are enough. The app works out how long you've been here, so it stays current.") {
                VStack(alignment: .leading, spacing: 14) {
                    MonthYearPicker(date: $draft.situation.firstArrival)
                    ChoiceButton(title: "I'd rather not say", selected: false) {
                        draft.situation.firstArrival = nil
                        advance()
                    }
                    .frame(maxWidth: 260)
                }
            }
        case .applications:
            QuizCard(title: "Have you already applied for anything that hasn't been decided yet?",
                     hint: "Choose all that apply, or none. Each one links to the part of the law it falls under.") {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Situation.Application.allCases, id: \.self) { application in
                            ToggleCard(title: application.german, subtitle: application.english,
                                       isOn: draft.situation.pendingApplications.contains(application),
                                       ref: application.ref) {
                                draft.situation.pendingApplications.formSymmetricDifference([application])
                            }
                        }
                    }
                }
            }
        case .goals:
            QuizCard(title: "What are you trying to achieve?",
                     hint: "Choose all that apply. This picks which rules come first and which plans you see.") {
                VStack(spacing: 8) {
                    ForEach(Situation.Goal.allCases, id: \.self) { goal in
                        ToggleCard(title: goal.german, subtitle: goal.english, isOn: draft.situation.goals.contains(goal)) {
                            draft.situation.goals.formSymmetricDifference([goal])
                        }
                    }
                }
            }
        case .style:
            QuizCard(title: "How should I explain things?", hint: "The same choice as in Settings, where you can change it any time.") {
                StylePicker(style: $draft.preferences.style, onPick: advance)
            }
        case .summary:
            QuizCard(title: "Here's what I'll remember", hint: "Only on this Mac. Go back to change anything, or edit it later in Settings.") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            CatAvatar(fur: draft.avatar, size: 44)
                            Text(draft.preferredName.isEmpty ? "No name set" : draft.preferredName).font(.title3.weight(.semibold))
                        }
                        SummaryRow(label: "Language", value: languageName(draft.preferences.languageCode))
                        SummaryRow(label: "Nationality", value: nationalityText)
                        SummaryRow(label: "Status", value: draft.situation.status.map { "\($0.german) (\($0.english))" })
                        if draft.situation.status?.hasPurpose == true {
                            SummaryRow(label: "Purpose", value: draft.situation.purpose.map { "\($0.german) (\($0.english))" })
                        }
                        SummaryRow(label: "First arrived", value: draft.situation.firstArrival?.formatted(.dateTime.month(.wide).year()))
                        SummaryRow(label: "Applied for", value: draft.situation.pendingApplications.isEmpty ? nil
                                   : draft.situation.pendingApplications.map(\.german).sorted().joined(separator: ", "))
                        SummaryRow(label: "Interested in", value: draft.situation.goals.isEmpty ? nil
                                   : draft.situation.goals.map(\.german).sorted().joined(separator: ", "))
                        SummaryRow(label: "Explanations", value: draft.preferences.style.title)
                    }
                }
            }
        }
    }

    private var nationalityText: String? {
        if let code = draft.situation.countryCode {
            return Locale(identifier: "en").localizedString(forRegionCode: code)
        }
        switch draft.situation.nationalityGroup {
        case .euEEASwiss: return "EU, EEA or Swiss"
        case .nonEU: return "Another country"
        case nil: return nil
        }
    }

    // MARK: Flow

    /// Steps that move on as soon as an option is chosen, so they need no Continue button.
    private var isChoiceStep: Bool { [.language, .eu, .status, .purpose, .style].contains(step) }

    private func next(after step: Step) -> Step {
        let s = draft.situation
        switch step {
        case .language: return .name
        case .name: return .eu
        case .eu: return s.nationalityGroup == .nonEU ? .country : (s.nationalityGroup == .euEEASwiss ? .arrival : .status)
        case .country: return .status
        case .status: return s.status?.hasPurpose == true ? .purpose : .arrival
        case .purpose: return .arrival
        case .arrival: return .applications
        case .applications: return .goals
        case .goals: return .style
        case .style, .summary: return .summary
        }
    }

    private var progress: Double {
        let order: [Step] = [.language, .name, .eu, .country, .status, .purpose, .arrival, .applications, .goals, .style, .summary]
        return Double((order.firstIndex(of: step) ?? 0) + 1) / Double(order.count)
    }

    private func advance() {
        forward = true
        withAnimation(.smooth(duration: 0.35)) { path.append(next(after: step)) }
    }

    private func go(back: Bool) {
        forward = false
        withAnimation(.smooth(duration: 0.35)) { _ = path.popLast() }
    }

    private func finish(save: Bool) {
        if save {
            model.settings.preferences = draft.preferences
            model.settings.situation = draft.situation
            model.settings.preferredName = draft.preferredName
            model.settings.avatar = draft.avatar
        }
        model.settings.finishedOnboarding = true
        model.showingQuiz = false
    }
}

// MARK: Pieces

struct QuizCard<Content: View>: View {
    let title: String
    let hint: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Theme.serif(.title, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(hint)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content.padding(.top, 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }
}

struct ChoiceButton: View {
    let title: String
    var subtitle: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Theme.stamp) }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.stamp.opacity(0.10) : Color.secondary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.stamp : .clear, lineWidth: 1.5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct ToggleCard: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    var ref: LawRef? = nil
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3).foregroundStyle(isOn ? Theme.stamp : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let ref, let source = LawSource.v1.first(where: { $0.law == ref.law }) {
                    Link(destination: source.sectionURL(ref.section)) {
                        Text(ref.label).font(Theme.margin(16, relativeTo: .callout))
                    }
                    .foregroundStyle(Theme.stamp)
                    .help("Open \(ref.label) on gesetze-im-internet.de")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.07)))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct SummaryRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text(value ?? "Not set").foregroundStyle(value == nil ? .secondary : .primary)
        }
    }
}

extension Situation.Goal {
    var german: String {
        switch self {
        case .extend: "Verlängerung"
        case .changePurpose: "Zweckwechsel"
        case .permanentResidence: "Niederlassungserlaubnis / Daueraufenthalt"
        case .citizenship: "Einbürgerung"
        case .bringFamily: "Familiennachzug"
        case .changeJob: "Arbeitgeberwechsel"
        case .liveAbroad: "Längerer Auslandsaufenthalt"
        }
    }

    var english: String {
        switch self {
        case .extend: "extend my permit"
        case .changePurpose: "change the purpose of my stay"
        case .permanentResidence: "stay permanently"
        case .citizenship: "become German"
        case .bringFamily: "bring my family here"
        case .changeJob: "change jobs"
        case .liveAbroad: "spend time abroad, e.g. to study or work"
        }
    }
}
