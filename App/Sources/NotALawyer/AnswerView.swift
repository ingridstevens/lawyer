import NotALawyerCore
import QuickLook
import SwiftUI

/// Explanation, conditions, the law with the quoted words highlighted, where to ask (spec §6, step 4).
struct AnswerView: View {
    @Environment(AppModel.self) private var model
    let answer: Answer
    var compactFooter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            MarginRow {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    if answer.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("The model didn't write an explanation for this one. Here's what the law it found says.")
                            .font(.title3).foregroundStyle(.secondary)
                    } else {
                        Text(answer.explanation)
                            .font(.title3)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !answer.verdictPhrases.isEmpty {
                        Label("This explanation sounds like a decision about your case. The app can't make that decision and may be wrong; read the quoted law below and ask an authority.", systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(Theme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            TopicNotesView(notes: answer.topicNotes)

            if !answer.conditions.isEmpty {
                ConditionsView(conditions: answer.conditions)
            }

            PlanLinkView(citations: answer.citations)

            let related = model.documents.related(to: answer.citations)
            if !related.isEmpty {
                MarginRow {
                    Image(systemName: "folder").foregroundStyle(.secondary).accessibilityHidden(true)
                } content: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your documents that may relate").font(.headline)
                        FlowRow(records: related)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 26) {
                ForEach(Array(answer.citations.enumerated()), id: \.offset) { _, citation in
                    StatuteExcerpt(citation: citation, alwaysShowGerman: model.settings.preferences.alwaysShowGerman)
                }
            }

            MarginRow { EmptyView() } content: { WhereToAskView(compact: compactFooter) }
        }
    }
}

/// What the law requires, in the model's words. Not tickable: the user's own checklist lives in
/// their plan, and `PlanLinkView` shows the plan items this answer covers.
struct ConditionsView: View {
    let conditions: [String]

    var body: some View {
        MarginRow {
            Text("\(conditions.count)")
                .font(Theme.margin(28, relativeTo: .title2))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityHidden(true)
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Pill(text: "What the law requires")
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(conditions.enumerated()), id: \.offset) { _, condition in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(Theme.stamp).frame(width: 5, height: 5).offset(y: -3)
                            Text(condition).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("In the model's words; the quotes below are the law itself. Only the authority decides whether these are met.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// The steps of the user's plans that this answer's law covers, ticked exactly as in the plan
/// (with proof), so the answer and the plan always agree.
struct PlanLinkView: View {
    @Environment(AppModel.self) private var model
    let citations: [VerifiedCitation]
    @State private var proofFor: PlanStep?
    @State private var proofPlan: Plan?
    @State private var previewURL: URL?

    private var matches: [(plan: Plan, steps: [PlanStep])] {
        let cited = Set(citations.map { "\($0.passage.section.law)|\($0.passage.section.number)|\($0.passage.paragraph.number ?? "")" })
        return model.visiblePlans.compactMap { plan in
            let steps = plan.steps.filter { step in
                step.refs.contains { cited.contains("\($0.law)|\($0.section)|\($0.paragraph ?? "")") }
            }
            return steps.isEmpty ? nil : (plan, steps)
        }
    }

    var body: some View {
        ForEach(matches, id: \.plan.id) { match in
            let done = match.plan.steps.filter { model.isDone($0, in: match.plan) }.count
            MarginRow {
                Image(systemName: "checklist").font(.title3).foregroundStyle(Theme.stamp).accessibilityHidden(true)
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("In your plan: \(match.plan.german)").font(.headline)
                        Text("\(done)/\(match.plan.steps.count)").foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        Button("Open plan") { model.sidebarSelection = .plan(match.plan.id) }.buttonStyle(.link)
                    }
                    ForEach(match.steps) { step in
                        let isDone = model.isDone(step, in: match.plan)
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                if isDone { model.setDone(false, step, in: match.plan) } else { proofPlan = match.plan; proofFor = step }
                            } label: {
                                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                    .font(.title3).foregroundStyle(isDone ? Theme.stamp : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help(isDone ? "Untick in your plan" : "Tick off in your plan, with your proof")
                            .accessibilityLabel(isDone ? "Ticked: \(step.title)" : "Not ticked: \(step.title)")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title).fixedSize(horizontal: false, vertical: true)
                                if let proof = model.proof(for: step, in: match.plan) {
                                    ProofSummary(proof: proof, previewURL: $previewURL)
                                }
                            }
                        }
                    }
                    Text("Ticking here ticks the same item in your plan. You'll be asked how you know.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.stamp.opacity(0.06)))
            }
        }
        .sheet(item: $proofFor) { step in
            if let plan = proofPlan { ProofSheet(plan: plan, step: step) }
        }
        .quickLookPreview($previewURL)
    }
}

/// One verified citation, set like an annotated statute: the section in the margin, the
/// official paragraph beside it with the quoted words highlighted, then the translation.
struct StatuteExcerpt: View {
    let citation: VerifiedCitation
    let alwaysShowGerman: Bool
    @State private var showGerman = false
    @State private var showWholeParagraph = false
    @State private var highlightVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var section: LawSection { citation.passage.section }
    private var paragraph: LawParagraph { citation.passage.paragraph }

    var body: some View {
        MarginRow {
            VStack(alignment: .trailing, spacing: 0) {
                Text("§ \(section.number)")
                    .font(Theme.margin(34, relativeTo: .title))
                    .foregroundStyle(Theme.stamp)

                if let number = paragraph.number {
                    Text("Abs. \(number)")
                        .font(Theme.margin(17, relativeTo: .headline))
                        .foregroundStyle(Theme.stamp.opacity(0.75))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(citation.passage.label)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(section.displayHeading) · \(section.law)")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 12)
                    Link("Official text", destination: section.sourceURL)
                        .font(.subheadline)
                        .help(section.sourceURL.absoluteString)
                }

                if let about = citation.about, !about.isEmpty {
                    Text(about)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .help("A machine-written summary of what this section is about")
                }

                if alwaysShowGerman || showGerman || (citation.translation ?? "").isEmpty {
                    lawText
                }

                if let translation = citation.translation, !translation.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(translation)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Machine translation of the highlighted words. The German text is the law.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !(alwaysShowGerman || showGerman) {
                        Button("Show the German original") { showGerman = true }
                            .buttonStyle(.link).font(.callout)
                    }
                }

                if citation.quoteMatched {
                    Text("Official text as of \(section.asOf.lawDate). Quote checked word for word.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("The model's quote didn't match the official wording exactly, so nothing is highlighted. The paragraph above is the official text as of \(section.asOf.lawDate); read it rather than the model's summary.",
                          systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.25)) { highlightVisible = true }
        }
    }

    /// The official paragraph with the quoted words highlighted. Long paragraphs show the
    /// sentences around the quote first.
    private var lawText: some View {
        let ranges = CitationChecker.ranges(of: citation.quote, in: paragraph.text)
        let (shown, isExcerpt) = excerpt(around: ranges)
        return VStack(alignment: .leading, spacing: 6) {
            Text(attributed(shown, ranges: ranges))
                .font(Theme.serif(.body))
                .lineSpacing(5)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.locale, Locale(identifier: "de"))
                .padding(.vertical, 2)
            if isExcerpt || showWholeParagraph {
                Button(showWholeParagraph ? "Show less" : "Show the whole paragraph") {
                    withAnimation(.smooth) { showWholeParagraph.toggle() }
                }
                .buttonStyle(.link).font(.callout)
            }
        }
    }

    private static let excerptLimit = 700

    private func excerpt(around ranges: [Range<String.Index>]) -> (Range<String.Index>, Bool) {
        let text = paragraph.text
        let all = text.startIndex..<text.endIndex
        guard !showWholeParagraph, text.count > Self.excerptLimit, let first = ranges.first, let last = ranges.last else {
            return (all, false)
        }
        let start = text.index(first.lowerBound, offsetBy: -160, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(last.upperBound, offsetBy: 160, limitedBy: text.endIndex) ?? text.endIndex
        // Snap to word boundaries.
        let s = start == text.startIndex ? start : (text[start...].firstIndex(of: " ").map { text.index(after: $0) } ?? start)
        let e = end == text.endIndex ? end : (text[..<end].lastIndex(of: " ") ?? end)
        return (s..<e, s != text.startIndex || e != text.endIndex)
    }

    private func attributed(_ shown: Range<String.Index>, ranges: [Range<String.Index>]) -> AttributedString {
        let text = paragraph.text
        var result = AttributedString()
        if shown.lowerBound != text.startIndex { result += AttributedString("… ") }
        var cursor = shown.lowerBound
        for r in ranges where r.lowerBound >= shown.lowerBound && r.upperBound <= shown.upperBound {
            result += AttributedString(text[cursor..<r.lowerBound])
            var marked = AttributedString(text[r])
            marked.backgroundColor = highlightVisible ? Theme.highlighter : .clear
            marked.foregroundColor = Theme.ink
            result += marked
            cursor = r.upperBound
        }
        result += AttributedString(text[cursor..<shown.upperBound])
        if shown.upperBound != text.endIndex { result += AttributedString(" …") }
        return result
    }
}

/// Shown when no rule in the sources answers the question (spec §6, step 5).
struct RefusalView: View {
    let answer: Answer
    var compactFooter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            MarginRow {
                Text("?").font(Theme.margin(34, relativeTo: .title)).foregroundStyle(.secondary).accessibilityHidden(true)
            } content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("I couldn't find a rule in my sources that answers this.")
                        .font(.title3.weight(.semibold))
                    Text("Try asking about one specific permit or step, or use the German term if you know it, like Niederlassungserlaubnis or Einbürgerung.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TopicNotesView(notes: answer.topicNotes)
            if !answer.closest.isEmpty {
                MarginRow {
                    Text("Looked at").font(.headline).foregroundStyle(.secondary)
                } content: {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(answer.closest, id: \.self) { passage in
                            Link("\(passage.section.label): \(passage.section.displayHeading)", destination: passage.section.sourceURL)
                        }
                    }
                }
            }
            MarginRow { EmptyView() } content: { WhereToAskView(compact: compactFooter) }
        }
    }
}

/// Where to get a binding answer. Ends every answer (spec §4).
struct WhereToAskView: View {
    /// One line instead of the full box, for answers after the first in a chat.
    var compact = false

    var body: some View {
        if compact {
            Text("For a binding answer, ask your Ausländerbehörde, a free Migrationsberatung or a migration lawyer.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("For a binding answer about your case, ask").font(.subheadline.weight(.semibold))
                lines.foregroundStyle(.secondary)
            }
            .padding(.leading, 14)
            .overlay(alignment: .leading) { Rectangle().fill(Theme.rule).frame(width: 2) }
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("your local Ausländerbehörde (foreigners' authority) or Einbürgerungsbehörde (naturalisation authority);")
            Text("a free Migrationsberatung: MBE for adults, or the Jugendmigrationsdienste if you're under 27;")
            Text("a lawyer specialising in migration law (Fachanwalt für Migrationsrecht).")
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Document chips that open the file.
struct FlowRow: View {
    @Environment(AppModel.self) private var model
    let records: [DocumentRecord]
    @State private var previewURL: URL?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(records.prefix(5)) { record in
                Button { previewURL = model.documents.fileURL(for: record) } label: {
                    Label(record.title, systemImage: record.kind.systemImage).lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(record.kind.german)
            }
        }
        .quickLookPreview($previewURL)
    }
}

/// Hand-written background for questions the law answers by leaving something out.
struct TopicNotesView: View {
    let notes: [TopicNote]

    var body: some View {
        ForEach(notes) { note in
            MarginRow {
                Image(systemName: "info.circle").foregroundStyle(.secondary).accessibilityHidden(true)
            } content: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Background").font(.subheadline.weight(.semibold))
                    Text(note.shown).fixedSize(horizontal: false, vertical: true)
                    Text("Written by the app's authors to explain how the law reads, not quoted from it. See \(note.sections.map(\.label).joined(separator: ", ")).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.stamp.opacity(0.07)))
            }
        }
    }
}
