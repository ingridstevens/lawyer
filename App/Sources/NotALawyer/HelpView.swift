import AppKit
import NotALawyerCore
import SwiftUI

// MARK: Free help

/// A free or low-cost source of help that exists across Germany. Listed because it exists;
/// the app has no relationship with any of them.
struct HelpResource: Identifiable {
    let id: String
    let name: String
    let german: String
    let what: String
    let forWhom: String
    let cost: String
    let icon: String
    let links: [(title: String, url: URL)]

    /// Checked on 1 October 2026; all return 200.
    static let all: [HelpResource] = [
        HelpResource(id: "mbe", name: "Migration counselling for adults", german: "Migrationsberatung für erwachsene Zuwanderer (MBE)",
                     what: "Advice on residence, work, language courses, family and everyday life. Counsellors can also help you prepare for the Ausländerbehörde.",
                     forWhom: "Adults who have moved to Germany. Run by welfare organisations such as Caritas, Diakonie, AWO and the Red Cross.",
                     cost: "Free and confidential", icon: "person.2.wave.2",
                     links: [("Find an office near you (BAMF-NAVI)", URL(string: "https://bamf-navi.bamf.de/de/Themen/Beratungsstellen/")!),
                             ("Online counselling in many languages (mbeon)", URL(string: "https://www.mbeon.de/")!)]),
        HelpResource(id: "jmd", name: "Youth migration services", german: "Jugendmigrationsdienste (JMD)",
                     what: "The same kind of counselling, for young people: residence, school, training, work.",
                     forWhom: "Young people aged 12 to 27 with a migration background.",
                     cost: "Free and confidential", icon: "figure.and.child.holdinghands",
                     links: [("Find an office near you (BAMF-NAVI)", URL(string: "https://bamf-navi.bamf.de/de/Themen/Beratungsstellen/")!),
                             ("Jugendmigrationsdienste", URL(string: "https://www.jugendmigrationsdienste.de/")!)]),
        HelpResource(id: "rlc", name: "Refugee Law Clinics", german: "Refugee Law Clinics",
                     what: "Free legal advice on residence and asylum law from law students, supervised by qualified lawyers.",
                     forWhom: "Anyone with a question about residence or asylum law, in many university cities.",
                     cost: "Free", icon: "building.columns",
                     links: [("Find a clinic", URL(string: "https://rlc-deutschland.de/rlcs/")!)]),
        HelpResource(id: "fr", name: "Refugee councils", german: "Flüchtlingsräte der Länder",
                     what: "Independent organisations in each federal state that advise refugees and know the local rules and authorities.",
                     forWhom: "Refugees and people with a Duldung or Aufenthaltsgestattung, and the people helping them.",
                     cost: "Free", icon: "hands.and.sparkles",
                     links: [("Find the council for your state", URL(string: "https://www.fluechtlingsrat.de/landesfluechtlingsraete/")!)]),
        HelpResource(id: "abh", name: "Foreigners' authority", german: "Ausländerbehörde",
                     what: "The authority that decides on your residence permit. Only it can give a binding answer about your case.",
                     forWhom: "Everyone with a residence title. Which one is responsible depends on where you're registered.",
                     cost: "Fees apply to applications, not to questions", icon: "building.2",
                     links: [("Find your authority (BAMF-NAVI)", URL(string: "https://bamf-navi.bamf.de/de/Themen/Behoerden/")!)]),
        HelpResource(id: "einb", name: "Naturalisation authority", german: "Einbürgerungsbehörde",
                     what: "Decides on naturalisation. Often part of the same office as the Ausländerbehörde, or of your town or district.",
                     forWhom: "Anyone who wants to become German.",
                     cost: "Fees apply to the application", icon: "flag",
                     links: [("Federal Government guide to naturalisation", URL(string: "https://www.einbuergerung.de/")!)]),
        HelpResource(id: "lawyer", name: "Lawyer specialising in migration law", german: "Fachanwältin / Fachanwalt für Migrationsrecht",
                     what: "Binding legal advice on your individual case, and representation against a decision.",
                     forWhom: "Anyone, especially when there's a refusal, a deadline, or a lot at stake.",
                     cost: "Paid. Ask what a first consultation (Erstberatung) costs before you book. With a low income, you can apply for Beratungshilfe at your local Amtsgericht to cover most of it.",
                     icon: "briefcase",
                     links: [("Search the German Lawyers' Association directory", URL(string: "https://anwaltauskunft.de/anwaltssuche?fachanwalt=migrationsrecht")!),
                             ("Official register of all lawyers (BRAK)", URL(string: "https://www.brak.de/service/bundesweites-amtliches-anwaltsverzeichnis/")!)]),
    ]
}

struct HelpResourcesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Headline(text: "Free help near you", style: .largeTitle)
                    Text("These services exist across Germany. Use their finders to get the office nearest you; they open in your browser, and you type your town there. Nothing about you is sent from this app.")
                        .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Label("Not a Lawyer has no connection to any of these organisations and isn't recommending one over another. Check details and opening times on their own sites.",
                          systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                ForEach(HelpResource.all) { resource in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: resource.icon).font(.title2).foregroundStyle(Theme.stamp).frame(width: 34)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(resource.german).font(.title3.weight(.semibold))
                            Text(resource.name).foregroundStyle(.secondary)
                            Text(resource.what).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                            Label(resource.forWhom, systemImage: "person").font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Label(resource.cost, systemImage: "eurosign.circle").font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 14) {
                                ForEach(resource.links, id: \.url) { link in
                                    Link(destination: link.url) { Label(link.title, systemImage: "arrow.up.right.square") }
                                        .help(link.url.absoluteString)
                                }
                            }
                            .font(.callout)
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.06)))
                }

                Button { model.sidebarSelection = .prepareContact } label: {
                    Label("Prepare an email, call or visit", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: Theme.pageWidth)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .background(PageBackground())
        .navigationTitle("Free help near you")
    }
}

// MARK: Preparing contact

/// Builds a German email, phone script or visit checklist, with an English version, from the
/// user's situation, a topic and their questions. Template-based, so it's instant and says only
/// what the user entered. Nothing is sent; the user copies, prints or saves it.
struct ContactBrief {
    enum Recipient: String, CaseIterable, Identifiable {
        case auslaenderbehoerde, einbuergerungsbehoerde, counselling, lawyer
        var id: Self { self }
        var german: String {
            switch self {
            case .auslaenderbehoerde: "Ausländerbehörde"
            case .einbuergerungsbehoerde: "Einbürgerungsbehörde"
            case .counselling: "Migrationsberatung"
            case .lawyer: "Anwältin / Anwalt für Migrationsrecht"
            }
        }
        var english: String {
            switch self {
            case .auslaenderbehoerde: "foreigners' authority"
            case .einbuergerungsbehoerde: "naturalisation authority"
            case .counselling: "migration counselling"
            case .lawyer: "migration lawyer"
            }
        }
        var isAuthority: Bool { self == .auslaenderbehoerde || self == .einbuergerungsbehoerde }
    }

    enum Channel: String, CaseIterable, Identifiable {
        case email, phone, visit
        var id: Self { self }
        var title: String {
            switch self {
            case .email: "Email"
            case .phone: "Phone call"
            case .visit: "Visit in person"
            }
        }
        var icon: String {
            switch self {
            case .email: "envelope"
            case .phone: "phone"
            case .visit: "figure.walk"
            }
        }
    }

    /// What the contact is about.
    struct Topic: Hashable, Identifiable {
        let id: String
        let english: String
        let german: String
        /// "I would like to …" in German and English.
        let wantDE: String
        let wantEN: String
        let questions: [(de: String, en: String)]
        let documentKinds: [String]

        static func == (a: Topic, b: Topic) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }

        static let all: [Topic] = [
            Topic(id: "citizenship", english: "Becoming German", german: "Einbürgerung",
                  wantDE: "mich einbürgern lassen", wantEN: "apply for naturalisation",
                  questions: [("Welche Unterlagen muss ich für den Antrag einreichen?", "Which documents do I need to submit with the application?"),
                              ("Kann ich den Antrag online stellen?", "Can I apply online?"),
                              ("Wie lange dauert das Verfahren derzeit?", "How long does the procedure currently take?"),
                              ("Welche Gebühren fallen an?", "What fees are there?")],
                  documentKinds: Plan.citizenship.steps.flatMap(\.documentKinds)),
            Topic(id: "settlement", english: "Permanent residence", german: "Niederlassungserlaubnis",
                  wantDE: "eine Niederlassungserlaubnis beantragen", wantEN: "apply for a settlement permit",
                  questions: [("Welche Unterlagen muss ich einreichen?", "Which documents do I need to submit?"),
                              ("Ab wann kann ich den Antrag stellen?", "From when can I apply?"),
                              ("Wie vereinbare ich einen Termin?", "How do I make an appointment?")],
                  documentKinds: Plan.settlementPermit.steps.flatMap(\.documentKinds)),
            Topic(id: "extension", english: "Extending a permit", german: "Verlängerung der Aufenthaltserlaubnis",
                  wantDE: "meine Aufenthaltserlaubnis verlängern", wantEN: "extend my residence permit",
                  questions: [("Wann sollte ich die Verlängerung beantragen?", "When should I apply for the extension?"),
                              ("Welche Unterlagen brauchen Sie?", "Which documents do you need?"),
                              ("Bekomme ich eine Fiktionsbescheinigung, falls mein Titel vorher abläuft?", "Will I get a Fiktionsbescheinigung if my title expires before the decision?")],
                  documentKinds: ["residenceCard", "passport", "employmentContract", "payslip", "rentalContract", "registration"]),
            Topic(id: "abroad", english: "A longer stay abroad", german: "Längerer Auslandsaufenthalt",
                  wantDE: "für längere Zeit ins Ausland gehen, ohne meinen Aufenthaltstitel zu verlieren",
                  wantEN: "spend a longer time abroad without losing my residence title",
                  questions: [("Können Sie mir eine längere Frist für die Wiedereinreise bestimmen (§ 51 Abs. 1 Nr. 7 AufenthG)?", "Can you set a longer period for my return (§ 51 Abs. 1 Nr. 7 AufenthG)?"),
                              ("Wirkt sich der Auslandsaufenthalt auf meine Einbürgerung aus (§ 12b StAG)?", "Does the stay abroad affect my naturalisation (§ 12b StAG)?"),
                              ("Welche Unterlagen brauchen Sie dafür?", "Which documents do you need for this?")],
                  documentKinds: ["residenceCard", "passport", "registration"]),
            Topic(id: "family", english: "Family joining me", german: "Familiennachzug",
                  wantDE: "meine Familie nach Deutschland holen", wantEN: "bring my family to Germany",
                  questions: [("Welche Voraussetzungen gelten für den Familiennachzug in meinem Fall?", "Which conditions apply to family reunification in my case?"),
                              ("Wie viel Wohnraum und Einkommen muss ich nachweisen?", "How much living space and income do I need to show?")],
                  documentKinds: ["residenceCard", "rentalContract", "payslip", "employmentContract"]),
            Topic(id: "other", english: "Something else", german: "Sonstiges Anliegen",
                  wantDE: "eine Frage zu meinem Aufenthalt klären", wantEN: "ask a question about my residence",
                  questions: [], documentKinds: ["residenceCard", "passport"]),
        ]
    }

    var recipient: Recipient
    var channel: Channel
    var topic: Topic
    var questions: [String]
    var questionsEN: [String]
    var name: String
    var situation: Situation
    var includeSituation: Bool
    var documents: [DocumentRecord]
    var answerLanguage: String

    // MARK: Building

    private var nameOrPlaceholder: String { name.isEmpty ? "[Ihr Name]" : name }

    private func since(_ locale: String) -> String? {
        guard includeSituation, let date = situation.firstArrival else { return nil }
        return date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: locale)))
    }

    /// "eine Niederlassungserlaubnis", with the right article.
    private var statusDE: String? {
        guard includeSituation, let s = situation.status, s != .none, s != .euFreedomOfMovement else { return nil }
        let article: [Situation.Status: String] = [.visa: "ein", .duldung: "eine"]
        return "\(article[s] ?? "eine") \(s.german)"
    }

    private var statusEN: String? {
        guard includeSituation, let s = situation.status, s != .none, s != .euFreedomOfMovement else { return nil }
        return "a \(s.german) (\(s.english))"
    }

    /// Documents relevant to the topic, split into the ones the user has and the ones they don't.
    var documentChecklist: [(kind: DocumentKind, have: [DocumentRecord])] {
        var seen = Set<String>()
        let kinds = (["passport", "residenceCard"] + topic.documentKinds).filter { seen.insert($0).inserted }
            .compactMap(DocumentKind.init(rawValue:)).filter { $0 != .application }
        return kinds.map { kind in (kind, documents.filter { $0.kind == kind }) }
    }

    var german: String {
        var lines: [String] = []
        let intro = [since("de").map { "ich lebe seit \($0) in Deutschland" }, statusDE.map { "habe derzeit \($0)" }]
            .compactMap { $0 }.joined(separator: " und ")
        switch channel {
        case .email:
            lines.append("Betreff: Anfrage zu \(topic.german) – \(nameOrPlaceholder)")
            lines.append("")
            lines.append("Sehr geehrte Damen und Herren,")
            lines.append("")
            if !intro.isEmpty { lines.append(intro.prefix(1).uppercased() == intro.prefix(1) ? "\(intro)." : "\(intro)." ) }
            lines.append("Ich möchte \(topic.wantDE).")
            appendQuestionsDE(&lines)
            let have = documents.filter { d in documentChecklist.contains { $0.kind == d.kind } }
            if !have.isEmpty {
                lines.append("")
                lines.append("Folgende Unterlagen liegen mir bereits vor:")
                lines += have.map { "– \($0.kind.german)\($0.detail.map { " (\($0))" } ?? "")" }
            }
            lines.append("")
            switch recipient {
            case .auslaenderbehoerde, .einbuergerungsbehoerde:
                lines.append("Könnten Sie mir bitte mitteilen, welche Unterlagen ich noch benötige und wie ich einen Termin vereinbaren kann?")
            case .counselling:
                lines.append("Ich würde mich über einen Beratungstermin freuen. Bitte teilen Sie mir mit, wann das möglich ist\(answerLanguage == "de" ? "." : " und ob die Beratung auch auf \(languageNameDE) möglich ist.")")
            case .lawyer:
                lines.append("Bitte teilen Sie mir mit, ob Sie mich in dieser Angelegenheit beraten können und welche Kosten für eine Erstberatung entstehen.")
            }
            lines.append("")
            lines.append("Mit freundlichen Grüßen")
            lines.append(nameOrPlaceholder)
            if recipient.isAuthority { lines.append("Geburtsdatum: [TT.MM.JJJJ]") }
            lines.append("[Adresse]")
            lines.append("[Telefonnummer]")
            if recipient.isAuthority { lines.append("Aktenzeichen (falls vorhanden): [ ]") }
        case .phone:
            lines.append("Telefonat mit: \(recipient.german)")
            lines.append("")
            lines.append("„Guten Tag, mein Name ist \(nameOrPlaceholder).“")
            lines.append("„Ich rufe an, weil ich \(topic.wantDE) möchte.“")
            if !intro.isEmpty { lines.append("„\(intro.prefix(1).uppercased() + intro.dropFirst()).“") }
            appendQuestionsDE(&lines)
            lines.append("")
            lines.append("Hilfreiche Sätze:")
            lines += ["„Können Sie bitte etwas langsamer sprechen?“", "„Können Sie das bitte wiederholen?“",
                      "„Können Sie mir das bitte per E-Mail schicken?“", "„Wie schreibt man das?“",
                      "„Welche Unterlagen soll ich mitbringen?“", "„Darf ich mir Ihren Namen notieren?“"]
            if answerLanguage != "de" { lines.append("„Ist eine Beratung auch auf \(languageNameDE) möglich?“") }
            lines.append("")
            lines += ["Notizen", "Gesprächspartner/in: ______________________", "Datum und Uhrzeit: ______________________",
                      "Was wurde gesagt: ______________________", "Nächster Schritt: ______________________"]
        case .visit:
            lines.append("Termin bei: \(recipient.german)")
            lines.append("Datum und Uhrzeit: ______________________   Ort: ______________________")
            lines.append("")
            lines.append("Mitbringen:")
            lines.append("☐ Terminbestätigung")
            lines += documentChecklist.map { item in "\(item.have.isEmpty ? "☐" : "☑") \(item.kind.german)\(item.have.isEmpty ? "" : " (vorhanden)")" }
            lines.append("☐ Kopien aller Unterlagen")
            lines.append("")
            lines.append("Worum es geht: Ich möchte \(topic.wantDE).")
            appendQuestionsDE(&lines)
            lines.append("")
            lines += ["Notizen", "Gesprächspartner/in: ______________________", "Was wurde gesagt: ______________________",
                      "Was fehlt noch: ______________________", "Nächster Schritt: ______________________"]
        }
        return lines.joined(separator: "\n")
    }

    var english: String {
        var lines: [String] = []
        let intro = [since("en").map { "I have lived in Germany since \($0)" }, statusEN.map { "currently hold \($0)" }]
            .compactMap { $0 }.joined(separator: " and ")
        switch channel {
        case .email:
            lines.append("Subject: Enquiry about \(topic.english) – \(name.isEmpty ? "[your name]" : name)")
            lines.append("")
            lines.append("Dear Sir or Madam,")
            lines.append("")
            if !intro.isEmpty { lines.append("\(intro).") }
            lines.append("I would like to \(topic.wantEN).")
            appendQuestionsEN(&lines)
            let have = documents.filter { d in documentChecklist.contains { $0.kind == d.kind } }
            if !have.isEmpty {
                lines.append("")
                lines.append("I already have these documents:")
                lines += have.map { "– \($0.kind.english)\($0.detail.map { " (\($0))" } ?? "")" }
            }
            lines.append("")
            switch recipient {
            case .auslaenderbehoerde, .einbuergerungsbehoerde:
                lines.append("Could you please tell me which documents I still need and how I can make an appointment?")
            case .counselling:
                lines.append("I would like a counselling appointment. Please let me know when that's possible\(answerLanguage == "de" ? "." : " and whether it can be in \(languageNameEN).")")
            case .lawyer:
                lines.append("Please let me know whether you can advise me on this, and what a first consultation costs.")
            }
            lines.append("")
            lines.append("Kind regards")
            lines.append(name.isEmpty ? "[your name]" : name)
            if recipient.isAuthority { lines.append("Date of birth: [DD.MM.YYYY]") }
            lines += ["[address]", "[phone number]"]
            if recipient.isAuthority { lines.append("File number (if you have one): [ ]") }
        case .phone:
            lines.append("Call to: \(recipient.english)")
            lines.append("")
            lines.append("“Hello, my name is \(name.isEmpty ? "[your name]" : name).”")
            lines.append("“I'm calling because I would like to \(topic.wantEN).”")
            if !intro.isEmpty { lines.append("“\(intro).”") }
            appendQuestionsEN(&lines)
            lines.append("")
            lines.append("Useful phrases:")
            lines += ["“Could you speak a little more slowly, please?”", "“Could you repeat that, please?”",
                      "“Could you send me that by email, please?”", "“How do you spell that?”",
                      "“Which documents should I bring?”", "“May I note your name?”"]
            if answerLanguage != "de" { lines.append("“Is counselling also possible in \(languageNameEN)?”") }
            lines.append("")
            lines += ["Notes", "Spoke to: ______________________", "Date and time: ______________________",
                      "What they said: ______________________", "Next step: ______________________"]
        case .visit:
            lines.append("Appointment at: \(recipient.english)")
            lines.append("Date and time: ______________________   Place: ______________________")
            lines.append("")
            lines.append("Bring:")
            lines.append("☐ Appointment confirmation")
            lines += documentChecklist.map { item in "\(item.have.isEmpty ? "☐" : "☑") \(item.kind.english)\(item.have.isEmpty ? "" : " (you have this)")" }
            lines.append("☐ Copies of all documents")
            lines.append("")
            lines.append("What it's about: I would like to \(topic.wantEN).")
            appendQuestionsEN(&lines)
            lines.append("")
            lines += ["Notes", "Spoke to: ______________________", "What they said: ______________________",
                      "Still missing: ______________________", "Next step: ______________________"]
        }
        return lines.joined(separator: "\n")
    }

    private func appendQuestionsDE(_ lines: inout [String]) {
        guard !questions.isEmpty else { return }
        lines.append("")
        lines.append(channel == .email ? "Dazu habe ich folgende Fragen:" : "Meine Fragen:")
        lines += questions.enumerated().map { "\($0.offset + 1). \($0.element)" }
    }

    private func appendQuestionsEN(_ lines: inout [String]) {
        guard !questionsEN.isEmpty else { return }
        lines.append("")
        lines.append(channel == .email ? "My questions:" : "My questions:")
        lines += questionsEN.enumerated().map { "\($0.offset + 1). \($0.element)" }
    }

    private var languageNameDE: String { Locale(identifier: "de").localizedString(forLanguageCode: answerLanguage) ?? answerLanguage }
    private var languageNameEN: String { Locale(identifier: "en").localizedString(forLanguageCode: answerLanguage) ?? answerLanguage }
}

struct PrepareContactView: View {
    @Environment(AppModel.self) private var model
    @State private var recipient: ContactBrief.Recipient = .auslaenderbehoerde
    @State private var channel: ContactBrief.Channel = .email
    @State private var topic = ContactBrief.Topic.all[0]
    /// Questions as (German, English). Suggestions are bilingual; the user's own are kept as typed.
    @State private var questions: [(de: String, en: String)] = []
    @State private var newQuestion = ""
    @State private var includeSituation = true
    @State private var copied = false

    private var brief: ContactBrief {
        ContactBrief(recipient: recipient, channel: channel, topic: topic, questions: questions.map(\.de),
                     questionsEN: questions.map(\.en), name: model.settings.preferredName, situation: model.settings.situation,
                     includeSituation: includeSituation, documents: model.documents.records,
                     answerLanguage: model.settings.preferences.languageCode)
    }

    var body: some View {
        HSplitView {
            Form {
                Section("Who are you contacting?") {
                    Picker("Recipient", selection: $recipient) {
                        ForEach(ContactBrief.Recipient.allCases) { Text("\($0.german) (\($0.english))").tag($0) }
                    }
                    .labelsHidden()
                    Button("Find their contact details") { model.sidebarSelection = .helpResources }.buttonStyle(.link)
                }
                Section("How?") {
                    Picker("Channel", selection: $channel) {
                        ForEach(ContactBrief.Channel.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("About") {
                    Picker("Topic", selection: $topic) {
                        ForEach(ContactBrief.Topic.all) { Text("\($0.german) (\($0.english))").tag($0) }
                    }
                    .labelsHidden()
                    .onChange(of: topic) { questions = [] }
                    Toggle("Mention my situation (arrival date and residence title)", isOn: $includeSituation)
                }
                Section {
                    ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.de)
                                if q.en != q.de { Text(q.en).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button { questions.remove(at: i) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                        }
                    }
                    // A full-width text box, not a form row: the cursor starts on the left.
                    HStack(alignment: .top, spacing: 8) {
                        TextField("", text: $newQuestion, prompt: Text("Your own question (German if you can)"), axis: .vertical)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1...4)
                            .frame(maxWidth: .infinity)
                            .onSubmit(addQuestion)
                        Button("Add", action: addQuestion).disabled(newQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    let unused = topic.questions.filter { s in !questions.contains { $0.de == s.de } }
                    if !unused.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggestions").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(unused, id: \.de) { s in
                                Button { questions.append(s) } label: {
                                    Label { VStack(alignment: .leading) { Text(s.de); Text(s.en).font(.caption).foregroundStyle(.secondary) } }
                                    icon: { Image(systemName: "plus.circle") }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("Your questions")
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 460)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("In German, to use", systemImage: "text.quote").font(.headline)
                        Text(brief.german).font(Theme.serif(.body)).textSelection(.enabled).lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sheet))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.rule))
                        Label("In English, so you know what it says", systemImage: "character.bubble").font(.headline)
                        Text(brief.english).textSelection(.enabled).foregroundStyle(.secondary).lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if channel == .email {
                            Text("Fill in the parts in [brackets] before sending. The app doesn't send anything; copy this into your own email.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                }
                Divider()
                HStack {
                    Spacer()
                    Button { copy() } label: { Label(copied ? "Copied" : "Copy German text", systemImage: copied ? "checkmark" : "doc.on.doc") }
                    Button { BriefPrinter.print(brief) } label: { Label("Print or Save as PDF…", systemImage: "printer") }
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
            }
            .frame(minWidth: 380, maxWidth: .infinity)
        }
        .navigationTitle("Prepare an email, call or visit")
        .onAppear {
            if let goal = model.settings.situation.goals.first, let t = ContactBrief.Topic.all.first(where: { $0.id == topicID(for: goal) }) { topic = t }
            if topic.id == "citizenship" { recipient = .einbuergerungsbehoerde }
        }
    }

    private func topicID(for goal: Situation.Goal) -> String {
        switch goal {
        case .citizenship: "citizenship"
        case .permanentResidence: "settlement"
        case .extend: "extension"
        case .liveAbroad: "abroad"
        case .bringFamily: "family"
        default: "other"
        }
    }

    private func addQuestion() {
        let q = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        questions.append((q, q))
        newQuestion = ""
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(brief.german, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}

/// Prints the brief, German first, then English, through the standard print panel, which also
/// offers "Save as PDF".
@MainActor
enum BriefPrinter {
    static func print(_ brief: ContactBrief) {
        let text = NSMutableAttributedString()
        let title = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let body = NSFont(name: "Charter-Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let small = NSFont.systemFont(ofSize: 10)
        func add(_ s: String, _ font: NSFont, _ color: NSColor = .black) {
            text.append(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color]))
        }
        add("\(brief.channel.title): \(brief.recipient.german) – \(brief.topic.german)\n\n", title)
        add(brief.german + "\n\n\n", body)
        add("English\n\n", title)
        add(brief.english + "\n\n\n", body, .darkGray)
        add("Prepared with Not a Lawyer on \(Date().formatted(date: .long, time: .omitted)). This is not legal advice.", small, .gray)

        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 700))
        view.textStorage?.setAttributedString(text)
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 56; info.bottomMargin = 56; info.leftMargin = 56; info.rightMargin = 56
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.jobDisposition = .spool
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.jobTitle = "\(brief.recipient.german) – \(brief.topic.german)"
        operation.run()
    }
}
