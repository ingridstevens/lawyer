import Foundation

/// A small hand-made dictionary from everyday words, in several languages, to the
/// German legal terms the statutes use (spec §9). Matching is case-insensitive substring.
public enum QueryExpansion {
    static let dictionary: [(phrases: [String], terms: [String])] = [
        (["permanent residence", "permanent residency", "settlement permit", "stay permanently", "unbefristet",
          "niederlassung", "residencia permanente", "kalıcı oturum", "süresiz oturum", "постійне проживання",
          "постоянное проживание", "إقامة دائمة"],
         ["Niederlassungserlaubnis", "Daueraufenthalt-EU", "unbefristeter Aufenthaltstitel"]),
        (["citizenship", "naturalis", "naturaliz", "vatanda", "become german", "becoming german", "becoming a german",
          "become a german", "german citizen", "german nationality", "be german", "deutsch werden", "deutscher werden",
          "deutsche werden", "almanya vatanda", "alman vatanda", "german passport", "become german", "einbürger",
          "staatsangehörigkeit", "ciudadanía", "nacionalidad", "vatandaşlık", "громадянство", "гражданство", "جنسية"],
         // StAG has no section headings and says "einzubürgern", which "Einbürgerung*" doesn't match.
         ["Einbürgerung", "Staatsangehörigkeit", "einzubürgern", "eingebürgert"]),
        (["born in germany", "born here", "in deutschland geboren", "nacido en alemania", "almanya'da doğ",
          "народжен", "рожден"],
         ["Erwerb durch Geburt", "Geburt im Inland", "durch Geburt"]),
        (["together with me", "with me", "mit eingebürgert", "family be naturali", "my children become"],
         ["mit eingebürgert"]),
        (["dual citizenship", "two passports", "keep my nationality", "doppelte staatsangehörigkeit",
          "doble nacionalidad", "çifte vatandaşlık", "подвійне громадянство", "двойное гражданство"],
         ["Mehrstaatigkeit", "Aufgabe oder Verlust der bisherigen Staatsangehörigkeit"]),
        (["blue card", "blaue karte", "tarjeta azul", "mavi kart", "блакитна карта", "голубая карта", "البطاقة الزرقاء"],
         // The statutes decline it: "Blauen Karte EU".
         ["Blaue Karte EU", "Blauen Karte EU"]),
        (["skilled worker", "fachkraft", "qualified professional", "trabajador cualificado", "nitelikli",
          "кваліфікован", "квалифицирован"],
         ["Fachkraft", "Fachkräfte mit Berufsausbildung", "Fachkräfte mit akademischer Ausbildung"]),
        (["job seek", "looking for work", "look for a job", "job search", "find a job", "chancenkarte", "opportunity card", "buscar trabajo",
          "iş aramak", "пошук роботи", "поиск работы"],
         ["Chancenkarte", "Arbeitsplatzsuche"]),
        (["study", "student", "university", "studium", "estudiar", "estudiante", "öğrenci", "üniversite",
          "навчання", "студент", "учёба", "دراسة"],
         ["Studium", "Studienvorbereitung"]),
        (["after graduat", "after my degree", "after studies", "german degree", "abschluss in deutschland",
          "after university", "studied in germany", "studied here", "finishing my studies", "trained in germany"],
         ["inländisches Studium", "inländische Berufsausbildung", "Studium im Bundesgebiet", "Arbeitsplatzsuche"]),
        (["is german", "german husband", "german wife", "german spouse", "german partner", "german citizen",
          "german child", "deutsche frau", "deutscher mann", "deutschen ehe"],
         ["Familiennachzug zu Deutschen", "Ehegatten eines Deutschen"]),
        (["family", "spouse", "wife", "husband", "partner", "children", "child", "join me", "bring my",
          "familie", "ehegatte", "kind", "familia", "esposa", "esposo", "hijos", "aile", "eş", "çocuk",
          "сім'я", "дружина", "чоловік", "діти", "семья", "жена", "муж", "дети", "عائلة", "زوجة", "أطفال"],
         ["Familiennachzug", "Ehegattennachzug", "Kindernachzug"]),
        (["parents", "mother", "father", "eltern", "padres", "anne", "baba", "батьки", "родители"],
         ["Nachzug der Eltern", "sonstiger Familienangehöriger", "Eltern"]),
        (["language", "german level", "b1", "a1", "sprach", "deutschkenntnisse", "idioma", "dil", "мова", "язык"],
         ["Kenntnisse der deutschen Sprache", "Sprachkenntnisse", "Integrationskurs"]),
        (["integration course", "integrationskurs", "orientation course", "leben in deutschland"],
         ["Integrationskurs", "Orientierungskurs", "Rechts- und Gesellschaftsordnung"]),
        (["pension", "rentenversicherung", "contributions", "pensión", "emeklilik", "пенсі", "пенсия"],
         ["Rentenversicherung", "Pflichtbeiträge"]),
        (["benefits", "bürgergeld", "welfare", "social assistance", "income", "earn", "salary", "money",
          "gehalt", "lebensunterhalt", "ayuda social", "maaş", "зарплата", "допомога", "пособие"],
         ["Lebensunterhalt", "gesichert", "öffentliche Mittel", "Sozialgesetzbuch"]),
        (["extend", "extension", "renew", "verlänger", "prorrogar", "renovar", "uzatma", "продовжити", "продлить"],
         ["Verlängerung", "Aufenthaltserlaubnis"]),
        (["change job", "new employer", "switch job", "arbeitgeberwechsel", "cambiar de trabajo", "iş değiştir",
          "змінити роботу", "сменить работу"],
         ["Beschäftigung", "Zustimmung der Bundesagentur für Arbeit", "Arbeitgeber"]),
        (["self-employed", "freelance", "own business", "selbständig", "freiberuf", "autónomo", "serbest",
          "самозайнят", "фріланс", "фриланс"],
         ["selbständige Tätigkeit", "freiberufliche Tätigkeit"]),
        (["leave germany", "abroad", "outside germany", "travel", "ausland", "extranjero", "yurt dışı",
          "за кордон", "за границ"],
         ["Erlöschen", "erlischt", "Beendigung der Rechtmäßigkeit", "ausgereist", "Aufenthalt im Ausland"]),
        (["abroad", "outside germany", "leave germany", "leaving germany", "study in spain", "yurt dış", "yurtdış",
          "ispanya", "im ausland", "ins ausland", "за кордон", "за границ", "en el extranjero"],
         ["Ausland", "ausgereist", "nicht innerhalb von sechs Monaten", "gewöhnliche Aufenthalt im Inland"]),
        (["oturma iz", "oturum iz", "ikamet"], ["Aufenthaltserlaubnis", "Aufenthaltstitel"]),
        (["expires", "expired", "pending", "while my application", "still allowed to stay", "abgelaufen",
          "fiktion", "vence", "süresi dol", "закінч", "истек"],
         ["Fiktionsbescheinigung", "fortbestehend", "Beantragung des Aufenthaltstitels"]),
        (["visa", "visum", "visado", "vize", "віза", "виза", "تأشيرة"],
         ["Visum", "nationales Visum", "Einreise"]),
        (["eu citizen", "eu national", "freedom of movement", "freizügigkeit", "ciudadano de la ue",
          "громадянин єс", "гражданин ес",
          // Nationalities of EU/EEA states and Switzerland, so "I'm Italian" finds FreizügG/EU.
          "austrian", "belgian", "bulgarian", "croatian", "cypriot", "czech", "danish", "dutch", "estonian",
          "finnish", "french", "greek", "hungarian", "irish", "italian", "latvian", "lithuanian", "luxembourg",
          "maltese", "polish", "portuguese", "romanian", "slovak", "slovenian", "spanish", "swedish",
          "icelandic", "norwegian", "swiss", "liechtenstein"],
         ["Freizügigkeit", "Unionsbürger", "Daueraufenthaltsrecht", "Familienangehörige"]),
        (["refugee", "asylum", "flüchtling", "asyl", "refugiado", "mülteci", "біженець", "беженец", "لاجئ"],
         ["Flüchtling", "Schutzberechtigte", "Aufenthaltserlaubnis aus humanitären Gründen"]),
        (["ukrain", "україн", "украин", "أوكران"], ["vorübergehenden Schutz", "Aufenthaltsgewährung zum vorübergehenden Schutz"]),
        (["deport", "expel", "ausweis", "abschieb", "deportación", "sınır dışı", "депорт", "высыл"],
         ["Ausweisung", "Abschiebung"]),
        (["fee", "cost", "gebühr", "tasa", "ücret", "плата", "пошлина"],
         ["Gebühr", "Gebühren"]),
        (["criminal", "conviction", "crime", "straftat", "verurteil", "antecedentes", "sabıka", "судим"],
         ["Straftat", "Verurteilung", "Ausweisungsinteresse"]),
        (["work permit", "allowed to work", "arbeitserlaubnis", "erwerbstätigkeit", "permiso de trabajo",
          "çalışma izni", "дозвіл на роботу", "разрешение на работу"],
         ["Erwerbstätigkeit", "Beschäftigung", "Zustimmung der Bundesagentur für Arbeit"]),
        (["apprenticeship", "vocational training", "ausbildung", "formación profesional", "mesleki eğitim",
          "професійн", "профессиональн"],
         ["Berufsausbildung", "betriebliche Ausbildung"]),
        (["research", "researcher", "forschung", "investigador", "araştırma", "дослідник", "исследовател"],
         ["Forschung", "Forscher"]),
    ]

    /// The central section for each common topic: where a lawyer would start reading. Given the
    /// same ranking bonus as a section the planning step suggests, so the main rule is always in
    /// front of the model (the conditions for becoming German are § 10 StAG, whatever the wording).
    static let anchors: [(term: String, sections: [String])] = [
        ("Einbürgerung", ["§ 10 StAG"]),
        ("Mehrstaatigkeit", ["§ 10 StAG"]),
        ("Niederlassungserlaubnis", ["§ 9 AufenthG"]),
        ("Daueraufenthalt-EU", ["§ 9a AufenthG"]),
        ("Blaue Karte EU", ["§ 18g AufenthG", "§ 18c AufenthG"]),
        ("Familiennachzug", ["§ 27 AufenthG", "§ 29 AufenthG", "§ 30 AufenthG"]),
        ("Familiennachzug zu Deutschen", ["§ 28 AufenthG"]),
        ("Chancenkarte", ["§ 20a AufenthG"]),
        ("Studium", ["§ 16b AufenthG"]),
        ("Erlöschen", ["§ 51 AufenthG"]),
        ("Fiktionsbescheinigung", ["§ 81 AufenthG"]),
        ("Freizügigkeit", ["§ 2 FreizügG/EU", "§ 4a FreizügG/EU"]),
        ("Duldung", ["§ 60a AufenthG"]),
        ("Integrationskurs", ["§ 44 AufenthG"]),
    ]

    public static func anchorSections(for terms: [String]) -> [String] {
        var out: [String] = []
        for (term, sections) in anchors where terms.contains(term) {
            for s in sections where !out.contains(s) { out.append(s) }
        }
        return out
    }

    /// Search terms from the planning step, without law names and filler that match everything.
    public static func cleanPlannedTerms(_ terms: [String]) -> [String] {
        let noise: Set<String> = ["aufenthg", "stag", "beschv", "aufenthv", "freizügg/eu", "freizuegg/eu", "gesetz", "law",
                                  "conditions", "voraussetzungen", "germany", "deutschland", "german", "deutsch"]
        return terms.filter { !noise.contains($0.lowercased().trimmingCharacters(in: .whitespaces)) }
    }

    /// Score multipliers per law implied by the question itself, like `Situation.lawBoost`.
    public static func lawBoost(for question: String) -> [String: Double] {
        let terms = Set(terms(for: question))
        var boost: [String: Double] = [:]
        if terms.contains("Einbürgerung") || terms.contains("Erwerb durch Geburt") { boost["StAG"] = 2 }
        if terms.contains("Unionsbürger") { boost["FreizügG/EU"] = 2 }
        return boost
    }

    /// German search terms for the everyday words found in `question`.
    public static func terms(for question: String) -> [String] {
        let q = fold(question)
        let words = Set(q.components(separatedBy: CharacterSet.letters.inverted))
        return dictionary.filter { entry in entry.phrases.contains { matches(fold($0), q, words) } }.flatMap(\.terms)
    }

    /// Short phrases ("eş", "b1", "kind") only match whole words; folded, "eş" is "es", which
    /// would otherwise match inside "residence" and pull family law into every question.
    static func matches(_ phrase: String, _ question: String, _ words: Set<String>) -> Bool {
        phrase.count <= 3 ? words.contains(phrase) : question.contains(phrase)
    }

    /// Lowercase without accents, so "İspanya", "ispanya" and "Ispanya" all match, and
    /// "vatandaşlık" matches "vatandaslik". Plain lowercasing turns Turkish "İ" into "i" plus a
    /// combining dot, which then matches nothing.
    public static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
            .replacingOccurrences(of: "ı", with: "i")
    }

    /// Words from the question itself worth searching for: German legal words or section numbers
    /// the user typed. Short and very common German words are dropped.
    public static func questionWords(_ question: String) -> [String] {
        question
            .components(separatedBy: CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "-")).inverted)
            .filter { $0.count >= 5 && !stopwords.contains($0.lowercased()) }
    }

    static let stopwords: Set<String> = [
        "nicht", "einen", "einem", "einer", "eines", "durch", "werden", "wurde", "diese", "dieser", "dieses",
        "kann", "können", "haben", "meine", "meinen", "meiner", "welche", "welcher", "wann", "warum",
        "about", "after", "before", "where", "which", "would", "could", "should", "there", "their", "years",
        "germany", "deutschland", "german", "deutsch",
    ]
}
