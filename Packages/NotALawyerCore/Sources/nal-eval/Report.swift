import NotALawyerCore

enum Report {
    static func text(_ a: Answer) -> String {
        var out: [String] = []
        if a.refused {
            out.append("REFUSED: I couldn't find a rule in my sources that answers this.")
            if !a.closest.isEmpty { out.append("Closest: " + a.closest.map(\.section.label).joined(separator: ", ")) }
        } else {
            out.append(a.explanation)
            if !a.conditions.isEmpty { out.append("Conditions:\n" + a.conditions.map { "  [ ] \($0)" }.joined(separator: "\n")) }
            for c in a.citations {
                out.append("\(c.passage.label): „\(c.quote)“" + (c.translation.map { "\n  (machine translation) \($0)" } ?? ""))
            }
        }
        if a.refused, let raw = a.raw {
            out.append("Model said: refused=\(raw.refused)\n\(raw.explanation)\n" + raw.citations.map { "  \($0.law) \($0.section) Abs. \($0.paragraph ?? "-"): \($0.quote)" }.joined(separator: "\n"))
        }
        if !a.rejected.isEmpty { out.append("Removed citations: \(a.rejected)") }
        out.append("Search terms: " + a.searchTerms.joined(separator: ", "))
        out.append("Retrieved: " + a.retrieved.map(\.label).joined(separator: ", "))
        let order = ["plan", "search", "answer", "check"]
        out.append("Timings: " + order.compactMap { k in a.timings[k].map { "\(k) \(String(format: "%.1f", $0)) s" } }.joined(separator: " · ")
                   + " · law text given: \(a.promptCharacters) characters")
        let loose = a.citations.filter { !$0.quoteMatched }.map(\.passage.label)
        if !loose.isEmpty { out.append("Shown without exact quote: " + loose.joined(separator: ", ")) }
        return out.joined(separator: "\n\n")
    }
}
