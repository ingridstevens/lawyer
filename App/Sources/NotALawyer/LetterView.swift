import NotALawyerCore
import SwiftUI
import UniformTypeIdentifiers

/// A letter from an authority, read on this Mac, with its dates, deadlines, amounts, reference
/// numbers and laws picked out so the reader can check each one against the letter itself.
/// It shows what the letter says; it doesn't explain or assess it.
struct LetterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.readingLetter {
                ProgressView("Reading the letter on this Mac…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let letter = model.letter {
                LetterCheckView(letter: letter)
            } else {
                LetterIntake()
            }
        }
        .background(PageBackground())
        .navigationTitle(model.letter?.name ?? "Read a letter")
        .navigationSubtitle("Read only on this Mac")
    }
}

// MARK: Adding a letter

struct LetterIntake: View {
    @Environment(AppModel.self) private var model
    @State private var choosing = false
    @State private var pasted = ""
    @State private var dropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                MarginRow {
                    Image(systemName: "envelope.open").font(.system(size: 34)).foregroundStyle(Theme.stamp).accessibilityHidden(true)
                } content: {
                    VStack(alignment: .leading, spacing: 14) {
                        Headline(text: "Check a letter from an authority", style: .title)
                        Text("Add a letter from the Ausländerbehörde or another office: a PDF, a photo or a scan. The app reads it on this Mac and picks out the dates, deadlines, amounts, reference numbers and laws, so you can check each one against the letter.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Button("Choose a Letter…") { choosing = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            Text("or drop it anywhere here").foregroundStyle(.secondary)
                        }
                        Label("Stays on this Mac. Nothing is copied or kept unless you choose to save it.", systemImage: "lock")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }

                MarginRow {
                    Text("Or").font(.headline).foregroundStyle(.secondary)
                } content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Paste the letter's text").font(.headline)
                        TextEditor(text: $pasted)
                            .font(Theme.serif(.body))
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Theme.rule))
                            .accessibilityLabel("Letter text")
                        Button("Read This Text") { model.openLetter(pasted: pasted) }
                            .buttonStyle(.bordered)
                            .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                MarginRow {
                    EmptyView()
                } content: {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("This doesn't explain what the letter means or what you should do. A free counsellor can, and it helps to bring the letter and the numbers you've checked here.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        WhereToAskView()
                    }
                }
            }
            .frame(maxWidth: Theme.pageWidth)
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.stamp, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.openLetter(url)
            return true
        } isTargeted: { dropTargeted = $0 }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.pdf, .image, .plainText]) { result in
            if case .success(let url) = result { model.openLetter(url) }
        }
    }
}

// MARK: Checking a letter

struct LetterCheckView: View {
    @Environment(AppModel.self) private var model
    let letter: LetterReading
    /// The fact the reader clicked; its line is outlined on the original.
    @State private var focused: LetterFact.ID?
    @State private var saveError: String?

    var body: some View {
        HSplitView {
            if !letter.pages.isEmpty {
                LetterPagesView(letter: letter, focusedLine: focused.flatMap { id in letter.facts.first { $0.id == id }?.line })
                    .frame(minWidth: 300, idealWidth: 440)
            }
            facts.frame(minWidth: 420)
        }
        .toolbar {
            if letter.url != nil {
                ToolbarItem {
                    Button(letter.savedToDocuments ? "Saved to My Documents" : "Save to My Documents") {
                        do { try model.saveLetterToDocuments() } catch { saveError = error.localizedDescription }
                    }
                    .disabled(letter.savedToDocuments)
                    .help("Copies the letter into My documents on this Mac. Otherwise it's forgotten when you close it.")
                }
            }
            ToolbarItem {
                Button("Close Letter") { model.letter = nil }
                    .help("Forget this letter. The file itself isn't touched.")
            }
        }
        .alert("The letter couldn't be saved", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var facts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Headline(text: "Check what the app read", style: .title)
                    Text("Compare each item with your letter and say whether it matches. Scans and photos can be misread, and a wrong date or number matters.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !letter.facts.isEmpty {
                        let checked = letter.facts.filter { letter.checks[$0.id] != nil }.count
                        Text("\(checked) of \(letter.facts.count) checked")
                            .font(.callout.weight(.semibold)).foregroundStyle(Theme.stamp).monospacedDigit()
                    }
                }

                if letter.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LetterNote(text: "No text could be read from this file. Try a sharper photo in good light, or paste the text instead.")
                } else {
                    if letter.lines.contains(where: \.unsure) {
                        LetterNote(text: "Some lines were hard to read. They're marked in orange; check the numbers on them carefully.")
                    }
                    deadlines
                    group("Appointments", kinds: [.appointment])
                    group("Amounts", kinds: [.amount])
                    group("Reference numbers", kinds: [.reference],
                          note: "Give these when you call, write or visit, so the office can find your case.")
                    group("Laws mentioned", kinds: [.law])
                    group("Other dates", kinds: [.date])
                    if letter.facts.isEmpty {
                        LetterNote(text: "No dates, amounts or reference numbers were found. If the letter has them, the text may not have been read well: compare it with the original below.")
                    }
                    DisclosureGroup("Everything the app read") {
                        Text(fullText)
                            .font(Theme.serif(.body))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Not legal advice. This shows what the letter says; it doesn't explain it, or say whether the authority is right or what you should do.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    WhereToAskView()
                }
            }
            .frame(maxWidth: Theme.column, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }

    /// Always shown, even when empty: a deadline the app didn't find can still be on the letter.
    private var deadlines: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deadlines").font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
            let found = letter.facts.filter { $0.kind == .deadline || $0.kind == .period }
            if found.isEmpty {
                Text("No deadline was found in the text. That doesn't mean there isn't one: read the letter again, especially the end (Rechtsbehelfsbelehrung).")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(found) { row($0) }
            }
            Text("A missed deadline can matter. Go by the date on the letter itself, and ask a free counsellor to check it with you.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func group(_ title: String, kinds: Set<LetterFact.Kind>, note: String? = nil) -> some View {
        let found = letter.facts.filter { kinds.contains($0.kind) }
        if !found.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                ForEach(found) { row($0) }
                if let note { Text(note).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }

    private func row(_ fact: LetterFact) -> some View {
        LetterFactRow(
            fact: fact,
            unsure: letter.line(of: fact)?.unsure == true,
            check: letter.checks[fact.id],
            focused: focused == fact.id,
            setCheck: { model.letter?.checks[fact.id] = $0 },
            focus: { focused = fact.id })
    }

    /// The whole text, with the facts highlighted and hard-to-read lines in orange.
    private var fullText: AttributedString {
        var text = AttributedString()
        for (i, line) in letter.lines.enumerated() {
            var part = AttributedString(line.text + (i < letter.lines.count - 1 ? "\n" : ""))
            if line.unsure { part.foregroundColor = Theme.amber }
            text += part
        }
        for fact in letter.facts {
            let start = text.characters.index(text.startIndex, offsetBy: fact.id)
            let end = text.characters.index(start, offsetBy: fact.text.count)
            text[start..<end].backgroundColor = Theme.highlighter
        }
        return text
    }
}

struct LetterFactRow: View {
    @Environment(AppModel.self) private var model
    let fact: LetterFact
    let unsure: Bool
    let check: LetterReading.Check?
    let focused: Bool
    let setCheck: (LetterReading.Check?) -> Void
    let focus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fact.text)
                .font(.title3.weight(.semibold)).monospacedDigit()
                .textSelection(.enabled)
            Text(snippet)
                .font(Theme.serif(.body)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("In the letter: \(fact.snippet)")
            if let warning = fact.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
            }
            if unsure {
                Label("This line was hard to read. Compare it with the letter.", systemImage: "eye.trianglebadge.exclamationmark")
                    .font(.callout).foregroundStyle(Theme.amber)
            }
            HStack(spacing: 10) {
                switch check {
                case nil:
                    Text("Is this what your letter says?").font(.callout)
                    Button("Yes") { setCheck(.matches) }.buttonStyle(.bordered)
                    Button("No") { setCheck(.differs) }.buttonStyle(.bordered)
                case .matches:
                    Label("Matches your letter", systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(Theme.stamp)
                    Button("Undo") { setCheck(nil) }.buttonStyle(.link)
                case .differs:
                    Label("Doesn't match. Go by the letter itself, and mention it to whoever helps you.", systemImage: "xmark.circle.fill")
                        .font(.callout).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                    Button("Undo") { setCheck(nil) }.buttonStyle(.link)
                }
                Spacer(minLength: 0)
                if fact.kind == .law && fact.warning == nil {
                    Button("Ask what this law says") {
                        model.newChat()
                        model.ask("What does \(fact.text) say?")
                    }
                    .buttonStyle(.link)
                    .help("Starts a chat about this law. Nothing from your letter is used.")
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(focused ? Theme.stamp.opacity(0.09) : Color.secondary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Theme.stamp.opacity(0.5) : .clear))
        .contentShape(.rect)
        .onTapGesture(perform: focus)
        .accessibilityElement(children: .contain)
    }

    private var snippet: AttributedString {
        var text = AttributedString(fact.snippet)
        if let range = text.range(of: fact.text) {
            text[range].backgroundColor = Theme.highlighter
            text[range].foregroundColor = Theme.ink
        }
        return text
    }
}

/// The original pages, with hard-to-read lines marked and the clicked fact's line outlined.
struct LetterPagesView: View {
    let letter: LetterReading
    let focusedLine: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(letter.pages.indices, id: \.self) { page in
                        Image(nsImage: letter.pages[page])
                            .resizable()
                            .scaledToFit()
                            .overlay { GeometryReader { geometry in marks(on: page, size: geometry.size) } }
                            .background(.white)
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                            .accessibilityLabel("Original letter, page \(page + 1) of \(letter.pages.count)")
                    }
                }
                .padding(16)
            }
            .background(Color.secondary.opacity(0.08))
            .onChange(of: focusedLine) {
                guard let focusedLine else { return }
                withAnimation(.smooth) { proxy.scrollTo("line-\(focusedLine)", anchor: .center) }
            }
        }
    }

    @ViewBuilder private func marks(on page: Int, size: CGSize) -> some View {
        ForEach(letter.lines.indices, id: \.self) { index in
            let line = letter.lines[index]
            if line.page == page, let box = line.box, line.unsure || index == focusedLine {
                let tint = index == focusedLine ? Theme.stamp : Theme.amber
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint.opacity(0.18))
                    .stroke(tint, lineWidth: index == focusedLine ? 2 : 1)
                    .frame(width: box.width * size.width + 6, height: box.height * size.height + 4)
                    .position(x: box.midX * size.width, y: (1 - box.midY) * size.height)
                    .id("line-\(index)")
                    .accessibilityHidden(true)
            }
        }
    }
}

/// An amber note inside the letter page.
struct LetterNote: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(Theme.amber)
            .fixedSize(horizontal: false, vertical: true)
    }
}
