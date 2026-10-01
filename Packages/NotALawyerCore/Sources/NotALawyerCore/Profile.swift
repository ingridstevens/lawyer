import Foundation

/// How the app talks to the user (spec §5).
public struct AnswerPreferences: Sendable, Hashable, Codable {
    /// One setting for tone and reading level together.
    public enum Style: String, Sendable, Codable, CaseIterable {
        /// Not a lawyer: everyday words, every legal term explained.
        case explain
        /// Smart but busy: the key point first, then short bullets. No walls of text.
        case scannable
        /// Knows the terms: precise legal vocabulary and more detail.
        case expert

        public var title: String {
            switch self {
            case .explain: "Explain it to me"
            case .scannable: "Quick and scannable"
            case .expert: "Use the legal terms"
            }
        }

        public var subtitle: String {
            switch self {
            case .explain: "I'm not a lawyer. Use everyday words and explain any legal term."
            case .scannable: "The key point first, then short bullet points. No walls of text."
            case .expert: "I know the vocabulary. Be precise and use the legal terms."
            }
        }
    }

    /// BCP 47 code, e.g. "en", "de", "tr", "uk".
    public var languageCode: String
    public var style: Style
    /// Show the official German text next to every translation, or only when the user opens it.
    /// Quotes are checked and kept either way.
    public var alwaysShowGerman: Bool

    public init(languageCode: String = "en", style: Style = .explain, alwaysShowGerman: Bool = true) {
        self.languageCode = languageCode
        self.style = style
        self.alwaysShowGerman = alwaysShowGerman
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        languageCode = (try? c.decode(String.self, forKey: .languageCode)) ?? "en"
        style = (try? c.decode(Style.self, forKey: .style)) ?? .explain
        alwaysShowGerman = (try? c.decode(Bool.self, forKey: .alwaysShowGerman)) ?? true
    }

    /// English name of the language, for prompts: "Turkish".
    public var languageName: String {
        Locale(identifier: "en").localizedString(forLanguageCode: languageCode) ?? languageCode
    }
}

/// The user's situation. Every field is optional. Only used to choose which rules to
/// search and to phrase explanations; never to decide eligibility (spec §4, §5).
///
/// Names are German first, because people know their permit by the German word on the card.
public struct Situation: Sendable, Hashable, Codable {
    public enum NationalityGroup: String, Sendable, Codable, CaseIterable { case euEEASwiss, nonEU }

    public enum Status: String, Sendable, Codable, CaseIterable {
        case none, visa, residencePermit, blueCard, opportunityCard, settlementPermit, permanentResidenceEU
        case fiktionsbescheinigung, aufenthaltsgestattung, duldung, euFreedomOfMovement

        public var german: String {
            switch self {
            case .none: "Noch kein Aufenthaltstitel"
            case .visa: "Visum"
            case .residencePermit: "Aufenthaltserlaubnis"
            case .blueCard: "Blaue Karte EU"
            case .opportunityCard: "Chancenkarte"
            case .settlementPermit: "Niederlassungserlaubnis"
            case .permanentResidenceEU: "Erlaubnis zum Daueraufenthalt-EU"
            case .fiktionsbescheinigung: "Fiktionsbescheinigung"
            case .aufenthaltsgestattung: "Aufenthaltsgestattung"
            case .duldung: "Duldung"
            case .euFreedomOfMovement: "Freizügigkeit (EU/EWR/Schweiz)"
            }
        }

        public var english: String {
            switch self {
            case .none: "no residence title yet"
            case .visa: "visa"
            case .residencePermit: "temporary residence permit"
            case .blueCard: "EU Blue Card"
            case .opportunityCard: "opportunity card for job seekers"
            case .settlementPermit: "permanent settlement permit"
            case .permanentResidenceEU: "EU long-term residence permit"
            case .fiktionsbescheinigung: "certificate letting you stay while an application is decided"
            case .aufenthaltsgestattung: "permission to stay during the asylum procedure"
            case .duldung: "temporary suspension of deportation"
            case .euFreedomOfMovement: "free movement as an EU/EEA/Swiss citizen or their family"
            }
        }

        /// Only these titles are issued for a stated purpose (Aufenthaltszweck).
        public var hasPurpose: Bool { self == .visa || self == .residencePermit }
    }

    /// The purpose written on a visa or residence permit (Aufenthaltszweck), not what the person does.
    public enum Purpose: String, Sendable, Codable, CaseIterable {
        case work, study, family, humanitarian, other

        public var german: String {
            switch self {
            case .work: "Erwerbstätigkeit"
            case .study: "Ausbildung oder Studium"
            case .family: "Familiäre Gründe"
            case .humanitarian: "Humanitäre Gründe"
            case .other: "Sonstige Gründe"
            }
        }

        public var english: String {
            switch self {
            case .work: "work"
            case .study: "training or study"
            case .family: "family reasons"
            case .humanitarian: "humanitarian reasons"
            case .other: "other reasons"
            }
        }
    }

    public enum Goal: String, Sendable, Codable, CaseIterable {
        case extend, changePurpose, permanentResidence, citizenship, bringFamily, changeJob, liveAbroad
    }

    /// Applications already submitted and not yet decided.
    public enum Application: String, Sendable, Codable, CaseIterable {
        case citizenship, settlementPermit, permanentResidenceEU, permitExtension, blueCard, skilledWorker
        case opportunityCard, familyReunification, otherPermit

        public var german: String {
            switch self {
            case .citizenship: "Einbürgerung"
            case .settlementPermit: "Niederlassungserlaubnis"
            case .permanentResidenceEU: "Erlaubnis zum Daueraufenthalt-EU"
            case .permitExtension: "Verlängerung der Aufenthaltserlaubnis"
            case .blueCard: "Blaue Karte EU"
            case .skilledWorker: "Aufenthaltserlaubnis als Fachkraft"
            case .opportunityCard: "Chancenkarte"
            case .familyReunification: "Familiennachzug"
            case .otherPermit: "Anderer Aufenthaltstitel oder Zweckwechsel"
            }
        }

        public var english: String {
            switch self {
            case .citizenship: "citizenship"
            case .settlementPermit: "permanent settlement permit"
            case .permanentResidenceEU: "EU long-term residence permit"
            case .permitExtension: "extension of a residence permit"
            case .blueCard: "EU Blue Card"
            case .skilledWorker: "residence permit as a skilled worker"
            case .opportunityCard: "opportunity card for job seekers"
            case .familyReunification: "family joining you, or you joining family"
            case .otherPermit: "another residence title, or a change of purpose"
            }
        }

        /// Where the law sets out this application, so the user can look it up.
        public var ref: LawRef {
            switch self {
            case .citizenship: LawRef("StAG", "10")
            case .settlementPermit: LawRef("AufenthG", "9")
            case .permanentResidenceEU: LawRef("AufenthG", "9a")
            case .permitExtension: LawRef("AufenthG", "8")
            case .blueCard: LawRef("AufenthG", "18g")
            case .skilledWorker: LawRef("AufenthG", "18b")
            case .opportunityCard: LawRef("AufenthG", "20a")
            case .familyReunification: LawRef("AufenthG", "27")
            case .otherPermit: LawRef("AufenthG", "81")
            }
        }
    }

    /// Set by hand, or derived from `countryCode` when a country is chosen.
    public var nationalityGroup: NationalityGroup?
    /// ISO 3166 region code of the user's nationality, e.g. "TR".
    public var countryCode: String?
    public var status: Status?
    public var purpose: Purpose?
    /// Month of first arrival in Germany. Stored as a date so the time in Germany stays current.
    public var firstArrival: Date?
    public var goals: Set<Goal>
    public var pendingApplications: Set<Application>

    public init(nationalityGroup: NationalityGroup? = nil, countryCode: String? = nil, status: Status? = nil,
                purpose: Purpose? = nil, firstArrival: Date? = nil, goals: Set<Goal> = [],
                pendingApplications: Set<Application> = []) {
        self.nationalityGroup = nationalityGroup
        self.countryCode = countryCode
        self.status = status
        self.purpose = purpose
        self.firstArrival = firstArrival
        self.goals = goals
        self.pendingApplications = pendingApplications
    }

    public init(from decoder: any Decoder) throws {
        // Every field is optional so settings saved by an older version still load.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nationalityGroup = try? c.decodeIfPresent(NationalityGroup.self, forKey: .nationalityGroup)
        countryCode = try? c.decodeIfPresent(String.self, forKey: .countryCode)
        status = try? c.decodeIfPresent(Status.self, forKey: .status)
        purpose = try? c.decodeIfPresent(Purpose.self, forKey: .purpose)
        firstArrival = try? c.decodeIfPresent(Date.self, forKey: .firstArrival)
        // Decoded one by one, so an application type a future version drops doesn't wipe the rest.
        let rawApplications = (try? c.decodeIfPresent([String].self, forKey: .pendingApplications)) ?? []
        pendingApplications = Set(rawApplications.compactMap(Application.init(rawValue:)))
        let rawGoals = (try? c.decodeIfPresent([String].self, forKey: .goals)) ?? []
        goals = Set(rawGoals.compactMap(Goal.init(rawValue:)))
    }

    public var isEmpty: Bool { self == Situation() }

    /// EU and EEA member states plus Switzerland: the countries covered by FreizügG/EU.
    public static let euEEASwissCodes: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT",
        "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "IS", "LI", "NO", "CH",
    ]

    public static func nationalityGroup(forCountry code: String) -> NationalityGroup {
        euEEASwissCodes.contains(code.uppercased()) ? .euEEASwiss : .nonEU
    }

    public var effectiveNationalityGroup: NationalityGroup? {
        countryCode.map(Self.nationalityGroup(forCountry:)) ?? nationalityGroup
    }

    /// Whole years since first arrival, as of `now`.
    public func yearsInGermany(now: Date = Date()) -> Int? {
        guard let firstArrival else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.year], from: firstArrival, to: now).year
    }

    /// Score multipliers per law, so the user's situation pulls the right law up (spec §9).
    public var lawBoost: [String: Double] {
        var boost: [String: Double] = [:]
        if effectiveNationalityGroup == .euEEASwiss || status == .euFreedomOfMovement {
            boost["FreizügG/EU"] = 2.5; boost["AufenthG"] = 0.7
        }
        if effectiveNationalityGroup == .nonEU { boost["FreizügG/EU"] = 0.5 }
        if goals.contains(.citizenship) || pendingApplications.contains(.citizenship) { boost["StAG", default: 1] *= 1.8 }
        if purpose == .work || status == .blueCard { boost["BeschV", default: 1] *= 1.2 }
        return boost
    }

    /// German terms implied by the situation, added to the search.
    public var searchTerms: [String] {
        var terms: [String] = []
        switch status {
        case .blueCard: terms += ["Blaue Karte EU"]
        case .opportunityCard: terms += ["Chancenkarte"]
        case .settlementPermit: terms += ["Niederlassungserlaubnis"]
        case .permanentResidenceEU: terms += ["Daueraufenthalt-EU"]
        case .fiktionsbescheinigung: terms += ["Fiktionsbescheinigung", "fortbestehend"]
        case .aufenthaltsgestattung: terms += ["Aufenthaltsgestattung"]
        case .duldung: terms += ["Duldung", "geduldet"]
        case .euFreedomOfMovement: terms += ["Freizügigkeit"]
        default: break
        }
        if goals.contains(.permanentResidence) { terms += ["Niederlassungserlaubnis"] }
        if goals.contains(.citizenship) { terms += ["Einbürgerung"] }
        if goals.contains(.extend) { terms += ["Verlängerung"] }
        if goals.contains(.bringFamily) { terms += ["Familiennachzug"] }
        if goals.contains(.changeJob) { terms += ["Beschäftigung", "Arbeitgeber"] }
        if goals.contains(.liveAbroad) { terms += ["Ausland", "ausgereist"] }
        if !pendingApplications.isEmpty { terms += ["Antrag"] }
        return terms
    }

    /// One plain-English line per known fact, for the prompt.
    public func promptDescription(now: Date = Date()) -> String {
        var lines: [String] = []
        if let code = countryCode {
            let name = Locale(identifier: "en").localizedString(forRegionCode: code) ?? code
            lines.append("Nationality: \(name)")
        }
        switch effectiveNationalityGroup {
        case .euEEASwiss: lines.append("Citizen of an EU/EEA country or Switzerland")
        case .nonEU: lines.append("Not an EU/EEA/Swiss citizen")
        case nil: break
        }
        if let status { lines.append("Current status: \(status.german) (\(status.english))") }
        if let purpose, status?.hasPurpose ?? true {
            lines.append("Purpose of the permit (Aufenthaltszweck): \(purpose.german) (\(purpose.english))")
        }
        if let firstArrival, let years = yearsInGermany(now: now) {
            let month = firstArrival.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en")))
            lines.append("First arrived in Germany: \(month), about \(years) years ago")
        }
        if !goals.isEmpty { lines.append("Interested in: \(goals.map(\.rawValue).sorted().joined(separator: ", "))") }
        if !pendingApplications.isEmpty {
            let names = pendingApplications.map { "\($0.german) (\($0.english))" }.sorted()
            lines.append("Has already applied, not yet decided: \(names.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }
}
