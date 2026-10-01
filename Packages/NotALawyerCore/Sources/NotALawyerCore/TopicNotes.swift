import Foundation

/// Hand-written background for questions whose answer the law gives by leaving something out.
///
/// Example: since the 2024 reform, the StAG no longer requires giving up a previous nationality.
/// No paragraph says "you may keep it"; the requirement is simply gone. Keyword search can't find
/// an absence, so for these topics the engine adds the relevant sections and this note.
///
/// Notes explain how to read the cited sections; they are never cited as law. The app shows them
/// labelled as background from the app's authors. Part of the legal review before release.
public struct TopicNote: Sendable, Hashable, Identifiable, Codable {
    public var id: String
    /// Lowercased phrases, in several languages, that trigger the note.
    public var triggers: [String]
    public var sections: [LawRef]
    /// For the model, in English. It explains; the answer still has to quote the sections.
    public var note: String
    /// For the user, in English.
    public var shown: String

    public static var all: [TopicNote] { [multipleNationality, staysAbroad] }

    static let multipleNationality = TopicNote(
            id: "multiple-nationality",
            triggers: ["dual citizenship", "dual nationality", "two passports", "keep my nationality", "keep my citizenship",
                       "keep my current citizenship", "keep my old", "give up my", "keep my turkish", "vatandaşlığımı kor",
                       "vatandaşlığımı kaybet", "iki vatandaş", "renounce", "multiple nationalit",
                       "mehrstaatigkeit", "doppelte staatsangehörigkeit", "doppelpass", "staatsangehörigkeit behalten",
                       "aufgeben", "doble nacionalidad", "çifte vatandaşlık", "подвійне громадянство", "двойное гражданство",
                       "الجنسية المزدوجة"],
            sections: [LawRef("StAG", "10", "1"), LawRef("StAG", "17", "1"), LawRef("StAG", "26", "1")],
            note: """
            Since 27 June 2024, German nationality law accepts multiple nationality. The conditions for \
            naturalisation in § 10 Abs. 1 StAG no longer include giving up a previous nationality, and \
            § 17 Abs. 1 StAG no longer lists acquiring a foreign nationality as a way to lose German \
            nationality. § 26 Abs. 1 StAG refers to Germans who hold several nationalities. Whether the \
            other country lets the person keep its nationality depends on that country's law, which this \
            app doesn't cover. Explain this, quote the sections, and say that the other country's rules \
            must be checked separately.
            """,
            shown: """
            Since June 2024, German law no longer asks you to give up your previous nationality. Whether \
            your other country lets you keep its nationality depends on that country's law, which this \
            app doesn't cover: check with its embassy or consulate.
            """
        )

    static let staysAbroad = TopicNote(
        id: "stays-abroad",
        triggers: ["abroad", "outside germany", "leave germany", "leaving germany", "study in spain", "study in another",
                   "live in another country", "move away", "year away", "months away", "im ausland", "ins ausland",
                   "auslandsaufenthalt", "ausreise", "yurt dış", "yurtdış", "ispanya", "başka ülke", "за кордон", "за границ",
                   "en el extranjero", "fuera de alemania", "خارج ألمانيا"],
        sections: [LawRef("AufenthG", "51", "1"), LawRef("AufenthG", "51", "4"), LawRef("StAG", "12b", "1")],
        note: """
        Stays abroad affect two different things. (1) The residence title: under § 51 Abs. 1 Nr. 7 \
        AufenthG it expires if the person stays away longer than six months, unless the Ausländerbehörde \
        set a longer period before they left. § 51 Abs. 4 says a longer period is usually set for a \
        temporary stay abroad if the person holds a Niederlassungserlaubnis. (2) The residence time \
        that counts towards naturalisation: under § 12b Abs. 1 StAG, stays abroad of up to six months \
        don't interrupt it; longer stays don't interrupt it if the person returns within the period the \
        Ausländerbehörde set. Explain both, quote the paragraphs, and say that the person should ask \
        their Ausländerbehörde before leaving. Don't say what will happen in their case.
        """,
        shown: """
        Time abroad matters twice: for keeping your residence permit, and for the years that count \
        towards citizenship. In both, six months is a key limit, and the Ausländerbehörde can set a \
        longer period, but only if you ask before you leave.
        """
    )

    public static func matching(_ question: String) -> [TopicNote] {
        let q = QueryExpansion.fold(question)
        let words = Set(q.components(separatedBy: CharacterSet.letters.inverted))
        var notes = all.filter { note in note.triggers.contains { QueryExpansion.matches(QueryExpansion.fold($0), q, words) } }
        // "I have Canadian citizenship and want to become German": a citizenship question that
        // names another country is a multiple-nationality question even without the usual phrases.
        if !notes.contains(multipleNationality), mentionsCitizenship(q), mentionsOtherCountry(q, words) {
            notes.append(multipleNationality)
        }
        return notes
    }

    static func mentionsCitizenship(_ q: String) -> Bool {
        ["citizenship", "nationality", "naturalis", "naturaliz", "staatsangehorig", "einburger", "vatandas",
         "nacionalidad", "ciudadania", "громадян", "гражданств", "جنسية"].contains { q.contains($0) }
    }

    /// Country names (in English and German) and common nationality words, other than Germany.
    static let otherCountries: [String] = {
        var names = Set<String>()
        for region in Locale.Region.isoRegions where region.identifier.count == 2 && region.identifier != "DE" {
            for lang in ["en", "de"] {
                if let name = Locale(identifier: lang).localizedString(forRegionCode: region.identifier) {
                    names.insert(QueryExpansion.fold(name))
                }
            }
        }
        names.formUnion(["american", "us citizen", "usa", "british", "turkish", "turkiye", "indian", "chinese", "russian",
                         "ukrainian", "syrian", "afghan", "iranian", "iraqi", "polish", "italian", "spanish", "french",
                         "brazilian", "mexican", "canadian", "australian", "japanese", "korean", "vietnamese", "nigerian",
                         "pakistani", "egyptian", "moroccan", "serbian", "bosnian", "kosovar", "albanian", "romanian",
                         "bulgarian", "greek", "dutch", "austrian", "swiss", "portuguese", "filipino", "indonesian",
                         "turk", "turkiye cumhuriyeti", "amerikanisch", "turkisch", "britisch"])
        return names.sorted()
    }()

    static func mentionsOtherCountry(_ q: String, _ words: Set<String>) -> Bool {
        otherCountries.contains { QueryExpansion.matches($0, q, words) && $0.count >= 4 || words.contains($0) }
    }
}
