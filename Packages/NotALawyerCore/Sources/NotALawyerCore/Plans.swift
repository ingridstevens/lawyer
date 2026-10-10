import Foundation

/// A pointer to one paragraph of the law.
public struct LawRef: Sendable, Hashable, Codable {
    public var law: String
    public var section: String
    public var paragraph: String?

    public init(_ law: String, _ section: String, _ paragraph: String? = nil) {
        self.law = law
        self.section = section
        self.paragraph = paragraph
    }

    public var label: String {
        paragraph.map { "§ \(section) Abs. \($0) \(law)" } ?? "§ \(section) \(law)"
    }
}

/// One item on a plan: a condition from the law or a step in the procedure.
public struct PlanStep: Sendable, Hashable, Identifiable {
    /// A condition is something you meet ("five years of residence"); an action is something
    /// you do ("apply to the authority"). They're ticked off with different words.
    public enum Kind: Sendable, Hashable { case condition, action }

    public var id: String
    public var title: String
    /// The German term people meet on forms and at the authority.
    public var german: String
    public var detail: String
    public var refs: [LawRef]
    /// Raw values of the app's document kinds that usually show this condition.
    public var documentKinds: [String]
    public var kind: Kind = .condition
    /// Steps in different plans with the same key are the same legal condition, so ticking one
    /// ticks them all. Only for conditions with the same wording in the law; similar but
    /// different ones (livelihood under § 9 vs § 9a, 60 vs 36 months of pension) stay separate.
    public var shared: String? = nil
}

/// A checklist towards a goal (spec: conditions checklist, extended to a whole procedure).
///
/// Plans list what the law requires in general and the usual steps. They never say whether
/// the user meets a condition: the user ticks items off themselves. Every item cites the
/// paragraph it comes from; tests check those paragraphs exist in the collection.
/// Hand-written from the official text as of September 2026, and part of the legal review
/// before release (spec §4).
public struct Plan: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var german: String
    public var summary: String
    public var steps: [PlanStep]

    public static let all: [Plan] = [citizenship, settlementPermit, settlementPermitSkilled, settlementPermitBlueCard, permanentResidenceEU]

    /// Every step, in any plan, that is the same condition as `step`, including itself.
    public static func sameCondition(as step: PlanStep) -> [(plan: Plan, step: PlanStep)] {
        guard let key = step.shared else { return [] }
        return all.flatMap { plan in plan.steps.filter { $0.shared == key }.map { (plan, $0) } }
    }

    /// Plans that fit the user's goals and status, most specific first.
    public static func suggested(for situation: Situation) -> [Plan] {
        var plans: [Plan] = []
        if situation.goals.contains(.permanentResidence) || situation.pendingApplications.contains(.settlementPermit) {
            if situation.status == .blueCard { plans.append(settlementPermitBlueCard) }
            if situation.purpose == .work || situation.status == .blueCard { plans.append(settlementPermitSkilled) }
            plans += [settlementPermit, permanentResidenceEU]
        }
        if situation.goals.contains(.citizenship) || situation.pendingApplications.contains(.citizenship) {
            plans.insert(citizenship, at: 0)
        }
        return plans
    }

    // MARK: Plans

    public static let citizenship = Plan(
        id: "citizenship", title: "Becoming German", german: "Einbürgerung",
        summary: "The conditions for naturalisation on application under § 10 StAG, and the usual way to apply.",
        steps: [
            PlanStep(id: "residence", title: "Five years of lawful, habitual residence in Germany",
                     german: "seit fünf Jahren rechtmäßig gewöhnlicher Aufenthalt",
                     detail: "Counted from when your stay in Germany became lawful and habitual.",
                     refs: [LawRef("StAG", "10", "1")], documentKinds: ["registration", "residenceCard"]),
            PlanStep(id: "abroad", title: "Long stays abroad haven't interrupted your residence",
                     german: "keine Unterbrechung des gewöhnlichen Aufenthalts (Auslandsaufenthalte)",
                     detail: "Stays abroad of up to six months don't interrupt it. Longer ones do, unless you came back within a period the Ausländerbehörde set before you left. Ask them before a long stay abroad.",
                     refs: [LawRef("StAG", "12b", "1")], documentKinds: ["registration"]),
            PlanStep(id: "identity", title: "Identity and nationality are clarified",
                     german: "Identität und Staatsangehörigkeit geklärt",
                     detail: "Usually shown with a valid passport.",
                     refs: [LawRef("StAG", "10", "1")], documentKinds: ["passport"]),
            PlanStep(id: "title", title: "A permanent right of residence or a qualifying residence title",
                     german: "unbefristetes Aufenthaltsrecht oder geeigneter Aufenthaltstitel",
                     detail: "Some temporary purposes (for example study or job seeking) don't count. The paragraph lists them.",
                     refs: [LawRef("StAG", "10", "1")], documentKinds: ["residenceCard"]),
            PlanStep(id: "livelihood", title: "You can support yourself and your dependants without Bürgergeld or social assistance",
                     german: "Lebensunterhalt ohne Leistungen nach SGB II oder XII",
                     detail: "There are exceptions, for example for people in full-time work for at least 20 of the last 24 months.",
                     refs: [LawRef("StAG", "10", "1")], documentKinds: ["payslip", "employmentContract", "taxAssessment"]),
            PlanStep(id: "conduct", title: "No criminal conviction",
                     german: "keine Verurteilung wegen einer rechtswidrigen Tat",
                     detail: "Minor penalties can be disregarded. See § 12a StAG.",
                     refs: [LawRef("StAG", "10", "1"), LawRef("StAG", "12a", "1")], documentKinds: []),
            PlanStep(id: "language", title: "German at level B1",
                     german: "ausreichende Kenntnisse der deutschen Sprache (B1)",
                     detail: "Shown with a B1 certificate, for example the Deutsch-Test für Zuwanderer, telc or Goethe.",
                     refs: [LawRef("StAG", "10", "1"), LawRef("StAG", "10", "4")], documentKinds: ["languageCertificate", "integrationCourse"], shared: "german-b1"),
            PlanStep(id: "knowledge", title: "Knowledge of the legal and social order and of life in Germany",
                     german: "Kenntnisse der Rechts- und Gesellschaftsordnung (Einbürgerungstest)",
                     detail: "Usually shown by passing the naturalisation test.",
                     refs: [LawRef("StAG", "10", "1"), LawRef("StAG", "10", "5")], documentKinds: ["citizenshipTest"]),
            PlanStep(id: "commitment", title: "Commitment to the free democratic basic order, and to Germany's historical responsibility",
                     german: "Bekenntnis zur freiheitlichen demokratischen Grundordnung (Nr. 1) und zur historischen Verantwortung Deutschlands (Nr. 1a)",
                     detail: "Declarations you sign as part of the application. Nr. 1a covers Germany's responsibility for the Nazi regime and its consequences, in particular the protection of Jewish life, and peaceful coexistence.",
                     refs: [LawRef("StAG", "10", "1")], documentKinds: []),
            PlanStep(id: "apply", title: "Apply to your naturalisation authority",
                     german: "Antrag bei der Einbürgerungsbehörde",
                     detail: "Naturalisation under § 10 happens only on application. Many authorities take applications online; ask yours which documents they want.",
                     refs: [LawRef("StAG", "10", "1")], documentKinds: ["application"], kind: .action),
        ]
    )

    public static let settlementPermit = Plan(
        id: "settlement", title: "Permanent residence", german: "Niederlassungserlaubnis (§ 9 AufenthG)",
        summary: "The general conditions for a settlement permit. Skilled workers and Blue Card holders have their own, often faster, rules.",
        steps: [
            PlanStep(id: "years", title: "Five years with a residence permit", german: "seit fünf Jahren Aufenthaltserlaubnis",
                     detail: "", refs: [LawRef("AufenthG", "9", "2")], documentKinds: ["residenceCard"]),
            PlanStep(id: "livelihood", title: "Your livelihood is secured", german: "Lebensunterhalt gesichert",
                     detail: "", refs: [LawRef("AufenthG", "9", "2")], documentKinds: ["payslip", "employmentContract", "taxAssessment"]),
            PlanStep(id: "pension", title: "60 months of pension contributions, or comparable provision",
                     german: "60 Monate Beiträge zur Rentenversicherung",
                     detail: "Your pension insurance record (Versicherungsverlauf) shows the months paid.",
                     refs: [LawRef("AufenthG", "9", "2")], documentKinds: ["pensionRecord"]),
            PlanStep(id: "security", title: "No public-security reasons against it", german: "keine Gründe der öffentlichen Sicherheit oder Ordnung",
                     detail: "", refs: [LawRef("AufenthG", "9", "2")], documentKinds: [], shared: "public-security"),
            PlanStep(id: "work", title: "Permitted to work, with any permits your work needs",
                     german: "Beschäftigung erlaubt; erforderliche Erlaubnisse",
                     detail: "", refs: [LawRef("AufenthG", "9", "2")], documentKinds: ["employmentContract", "residenceCard"]),
            PlanStep(id: "language", title: "Sufficient German (B1)", german: "ausreichende Kenntnisse der deutschen Sprache",
                     detail: "A completed integration course counts.", refs: [LawRef("AufenthG", "9", "2")],
                     documentKinds: ["languageCertificate", "integrationCourse"], shared: "german-b1"),
            PlanStep(id: "knowledge", title: "Basic knowledge of the legal and social order", german: "Grundkenntnisse der Rechts- und Gesellschaftsordnung",
                     detail: "Usually the Leben in Deutschland test, or a completed integration course.",
                     refs: [LawRef("AufenthG", "9", "2")], documentKinds: ["citizenshipTest", "integrationCourse"], shared: "basic-knowledge"),
            PlanStep(id: "housing", title: "Enough living space for you and your family", german: "ausreichender Wohnraum",
                     detail: "", refs: [LawRef("AufenthG", "9", "2")], documentKinds: ["rentalContract"], shared: "housing"),
            PlanStep(id: "apply", title: "Apply to your Ausländerbehörde", german: "Antrag bei der Ausländerbehörde",
                     detail: "Apply before your current permit expires.", refs: [LawRef("AufenthG", "81", "1")], documentKinds: ["application"], kind: .action),
        ]
    )

    public static let settlementPermitSkilled = Plan(
        id: "settlement-skilled", title: "Permanent residence for skilled workers", german: "Niederlassungserlaubnis für Fachkräfte (§ 18c Abs. 1)",
        summary: "For people with a residence title as a skilled worker (§§ 18a, 18b, 18d or 18g). Times are shorter after a degree or vocational training in Germany.",
        steps: [
            PlanStep(id: "years", title: "Three years with a skilled-worker title (two after a German degree or training)",
                     german: "seit drei Jahren Aufenthaltstitel nach §§ 18a, 18b, 18d oder 18g",
                     detail: "", refs: [LawRef("AufenthG", "18c", "1")], documentKinds: ["residenceCard", "degree"]),
            PlanStep(id: "job", title: "A job you're allowed to do under that title", german: "Arbeitsplatz nach §§ 18a, 18b, 18d oder 18g",
                     detail: "", refs: [LawRef("AufenthG", "18c", "1")], documentKinds: ["employmentContract"]),
            PlanStep(id: "pension", title: "36 months of pension contributions (24 after a German degree or training)",
                     german: "36 Monate Beiträge zur Rentenversicherung",
                     detail: "", refs: [LawRef("AufenthG", "18c", "1")], documentKinds: ["pensionRecord"]),
            PlanStep(id: "language", title: "Sufficient German (B1)", german: "ausreichende Kenntnisse der deutschen Sprache",
                     detail: "", refs: [LawRef("AufenthG", "18c", "1")], documentKinds: ["languageCertificate", "integrationCourse"], shared: "german-b1"),
            PlanStep(id: "general", title: "The general conditions from § 9: livelihood, security, work permits, basic knowledge, living space",
                     german: "Voraussetzungen des § 9 Abs. 2 Satz 1 Nr. 2, 4 bis 6, 8 und 9",
                     detail: "", refs: [LawRef("AufenthG", "18c", "1"), LawRef("AufenthG", "9", "2")],
                     documentKinds: ["payslip", "rentalContract", "citizenshipTest"]),
            PlanStep(id: "apply", title: "Apply to your Ausländerbehörde", german: "Antrag bei der Ausländerbehörde",
                     detail: "", refs: [LawRef("AufenthG", "81", "1")], documentKinds: ["application"], kind: .action),
        ]
    )

    public static let settlementPermitBlueCard = Plan(
        id: "settlement-bluecard", title: "Permanent residence with a Blue Card", german: "Niederlassungserlaubnis mit Blauer Karte EU (§ 18c Abs. 2)",
        summary: "For EU Blue Card holders: 27 months, or 21 months with B1 German.",
        steps: [
            PlanStep(id: "months", title: "27 months working with the Blue Card, with pension contributions (21 months with B1 German)",
                     german: "27 Monate Beschäftigung nach § 18g mit Beiträgen zur Rentenversicherung",
                     detail: "", refs: [LawRef("AufenthG", "18c", "2")], documentKinds: ["pensionRecord", "employmentContract", "residenceCard"]),
            PlanStep(id: "language", title: "Basic German (A1), or sufficient German (B1) for the 21-month route",
                     german: "einfache Kenntnisse der deutschen Sprache",
                     detail: "", refs: [LawRef("AufenthG", "18c", "2")], documentKinds: ["languageCertificate"]),
            PlanStep(id: "general", title: "The general conditions from § 9: livelihood, security, work permits, basic knowledge, living space",
                     german: "Voraussetzungen des § 9 Abs. 2 Satz 1 Nr. 2, 4 bis 6, 8 und 9",
                     detail: "", refs: [LawRef("AufenthG", "18c", "2"), LawRef("AufenthG", "9", "2")],
                     documentKinds: ["payslip", "rentalContract", "citizenshipTest"]),
            PlanStep(id: "apply", title: "Apply to your Ausländerbehörde", german: "Antrag bei der Ausländerbehörde",
                     detail: "", refs: [LawRef("AufenthG", "81", "1")], documentKinds: ["application"], kind: .action),
        ]
    )

    public static let permanentResidenceEU = Plan(
        id: "eu-longterm", title: "EU long-term residence", german: "Erlaubnis zum Daueraufenthalt – EU (§ 9a)",
        summary: "A permanent title that also eases moving to other EU countries. It isn't available for some temporary purposes, such as study.",
        steps: [
            PlanStep(id: "years", title: "Five years in Germany with a residence title", german: "seit fünf Jahren mit Aufenthaltstitel",
                     detail: "", refs: [LawRef("AufenthG", "9a", "2")], documentKinds: ["residenceCard"]),
            PlanStep(id: "income", title: "Livelihood secured by fixed and regular income", german: "feste und regelmäßige Einkünfte",
                     detail: "", refs: [LawRef("AufenthG", "9a", "2")], documentKinds: ["payslip", "employmentContract", "taxAssessment"]),
            PlanStep(id: "language", title: "Sufficient German (B1)", german: "ausreichende Kenntnisse der deutschen Sprache",
                     detail: "", refs: [LawRef("AufenthG", "9a", "2")], documentKinds: ["languageCertificate", "integrationCourse"], shared: "german-b1"),
            PlanStep(id: "knowledge", title: "Basic knowledge of the legal and social order", german: "Grundkenntnisse der Rechts- und Gesellschaftsordnung",
                     detail: "", refs: [LawRef("AufenthG", "9a", "2")], documentKinds: ["citizenshipTest", "integrationCourse"], shared: "basic-knowledge"),
            PlanStep(id: "security", title: "No public-security reasons against it", german: "keine Gründe der öffentlichen Sicherheit oder Ordnung",
                     detail: "", refs: [LawRef("AufenthG", "9a", "2")], documentKinds: [], shared: "public-security"),
            PlanStep(id: "housing", title: "Enough living space for you and your family", german: "ausreichender Wohnraum",
                     detail: "", refs: [LawRef("AufenthG", "9a", "2")], documentKinds: ["rentalContract"], shared: "housing"),
            PlanStep(id: "exclusions", title: "Your purpose of stay isn't one of the excluded ones", german: "kein Ausschluss nach § 9a Abs. 3",
                     detail: "For example study, or other stays that are temporary by nature.",
                     refs: [LawRef("AufenthG", "9a", "3")], documentKinds: ["residenceCard"]),
        ]
    )
}
