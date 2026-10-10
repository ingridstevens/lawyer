import AppKit
import NotALawyerCore
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// The user's own documents: certificates, test results, contracts, decisions. Copied into the
/// app's folder on this Mac and sorted automatically; answers and plans point to the ones that relate.
struct DocumentsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: DocumentRecord.ID?
    @State private var dropTargeted = false
    @State private var error: String?
    @State private var previewURL: URL?

    var body: some View {
        @Bindable var model = model
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PageBackground())
            .overlay {
                if dropTargeted {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.stamp, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in add(urls); return true } isTargeted: { dropTargeted = $0 }
            .inspector(isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) {
                if let id = selection, let record = model.documents.records.first(where: { $0.id == id }) {
                    DocumentDetail(record: record, preview: { previewURL = model.documents.fileURL(for: record) },
                                   deleted: { selection = nil })
                        .id(record.id)
                        .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
                }
            }
            .navigationTitle("My documents")
            .navigationSubtitle("Stored only on this Mac")
            .toolbar {
                ToolbarItem {
                    Button { model.importKind = nil; model.importingDocument = true } label: {
                        Label("Add Documents", systemImage: "plus")
                    }
                    .labelStyle(.titleAndIcon)
                    .help("Add PDFs, photos or scans (⌘O)")
                }
            }
            .fileImporter(isPresented: $model.importingDocument, allowedContentTypes: [.pdf, .image, .plainText],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): add(urls)
                case .failure(let e): error = e.localizedDescription
                }
            }
            .quickLookPreview($previewURL)
    }

    @ViewBuilder private var content: some View {
        if model.documents.records.isEmpty {
            ScrollView {
                MarginRow {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 34)).foregroundStyle(Theme.stamp)
                } content: {
                    VStack(alignment: .leading, spacing: 14) {
                        Headline(text: "Add the documents you already have", style: .title)
                        Text("Language certificates, your Einbürgerungstest result, your pension record (Versicherungsverlauf), payslips, contracts, letters from the Ausländerbehörde. The app sorts them by type and points to them in answers and plans.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Button("Add Documents…") { model.importKind = nil; model.importingDocument = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            Text("or drop files anywhere here").foregroundStyle(.secondary)
                        }
                        Label("Copied into the app's folder and read only on this Mac, to sort them. Nothing is uploaded.", systemImage: "lock")
                            .font(.callout).foregroundStyle(.secondary)
                        if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
            }
        } else {
            List(selection: $selection) {
                AddDocumentsBar(error: error)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()
                ForEach(DocumentKind.allCases) { kind in
                    let records = model.documents.records.filter { $0.kind == kind }
                    if !records.isEmpty {
                        Section {
                            ForEach(records) { record in
                                DocumentRow(record: record)
                                    .tag(record.id)
                                    .contextMenu {
                                        Button("Preview") { previewURL = model.documents.fileURL(for: record) }
                                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.documents.fileURL(for: record)]) }
                                        Button("Delete", role: .destructive) { model.documents.remove(record) }
                                    }
                            }
                        } header: {
                            Label("\(kind.german) (\(kind.english))", systemImage: kind.systemImage)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func add(_ urls: [URL]) {
        error = nil
        let kind = model.importKind
        model.importKind = nil
        for url in urls {
            do { selection = try model.documents.add(url, kind: kind).id } catch { self.error = "Couldn't add \(url.lastPathComponent): \(error.localizedDescription)" }
        }
    }
}

/// Always at the top of the list: a drop zone, and the types the user's plans still need.
struct AddDocumentsBar: View {
    @Environment(AppModel.self) private var model
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { model.importKind = nil; model.importingDocument = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down").font(.title2).foregroundStyle(Theme.stamp)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add more documents").font(.headline)
                        Text("Choose files, or drop them anywhere on this page. They're sorted automatically.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Choose…").padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Theme.stamp)).foregroundStyle(.white).font(.callout.weight(.semibold))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stamp.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            let missing = model.missingDocumentKinds
            if !missing.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Usually needed for your plans, not added yet").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    FlexibleRow(spacing: 6) {
                        ForEach(missing) { kind in
                            Button { model.importKind = kind; model.importingDocument = true } label: {
                                Label(kind.german, systemImage: "plus")
                                    .font(.callout)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                                    .contentShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .help("Add a \(kind.english); it'll be filed as \(kind.german)")
                        }
                    }
                }
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
            }
        }
        .padding(.vertical, 8)
    }
}

/// Lays children out left to right, wrapping onto new lines.
struct FlexibleRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, point) in rows(bounds.width, subviews).points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return (points, CGSize(width: maxX, height: y + lineHeight))
    }
}

struct DocumentRow: View {
    @Environment(AppModel.self) private var model
    let record: DocumentRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: model.documents.fileURL(for: record).path))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).lineLimit(1)
                HStack(spacing: 6) {
                    if model.documents.sorting.contains(record.id) {
                        ProgressView().controlSize(.mini)
                        Text("Reading to sort it…")
                    } else {
                        if let issued = record.issued { Text(issued.formatted(date: .abbreviated, time: .omitted)) }
                        if record.autoSorted { Text("Sorted automatically") }
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

struct DocumentDetail: View {
    @Environment(AppModel.self) private var model
    /// The details being edited. Saved only when the user presses Save.
    @State var record: DocumentRecord
    let preview: () -> Void
    let deleted: () -> Void
    @State private var userEdited = false
    @State private var justSaved = false

    private var stored: DocumentRecord? { model.documents.records.first { $0.id == record.id } }
    private var hasChanges: Bool { stored != record }
    /// Added in the last few minutes and never saved by the user: ask them to check it.
    private var isNew: Bool { !userEdited && Date().timeIntervalSince(record.added) < 300 && record.autoSorted }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: model.documents.fileURL(for: record).path))
                            .resizable().frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.originalName).font(.headline).lineLimit(2)
                            Text("Added \(record.added.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack {
                        Button { preview() } label: { Label("Preview", systemImage: "eye") }
                        Button { NSWorkspace.shared.activateFileViewerSelecting([model.documents.fileURL(for: record)]) } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                    }
                }
                if isNew {
                    Section {
                        Label("Check the details the app filled in, then press Save.", systemImage: "sparkles")
                            .foregroundStyle(Theme.stamp)
                    }
                }
                Section {
                    TextField("Title", text: edit(\.title))
                    Picker("Type", selection: Binding(get: { record.kind }, set: { record.kind = $0; record.autoSorted = false; userEdited = true })) {
                        ForEach(DocumentKind.allCases) { kind in Text("\(kind.german) (\(kind.english))").tag(kind) }
                    }
                    if record.autoSorted {
                        Text("Sorted automatically from what the document says. Change it if it's wrong.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Date on the document")
                            Spacer()
                            if record.issued != nil { Button("Clear") { record.issued = nil; userEdited = true }.buttonStyle(.link) }
                        }
                        MonthYearPicker(date: edit(\.issued), compact: true)
                    }
                    TextField("Note", text: edit(\.note), prompt: Text("e.g. all parts passed"), axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Details")
                }
                let plans = Plan.all.filter { plan in plan.steps.contains { $0.documentKinds.contains(record.kind.rawValue) } }
                if !plans.isEmpty {
                    Section("Relates to") {
                        ForEach(plans) { plan in
                            let steps = plan.steps.filter { $0.documentKinds.contains(record.kind.rawValue) }.map(\.title)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.german).fontWeight(.semibold)
                                Text(steps.joined(separator: "; ")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button("Delete Document", role: .destructive) {
                        model.documents.remove(record)
                        deleted()
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if justSaved && !hasChanges {
                    Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if hasChanges {
                    Text("Unsaved changes").foregroundStyle(.secondary)
                }
                Spacer()
                if hasChanges, let stored {
                    Button("Discard changes") { record = stored; userEdited = false }
                }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s")
                    .disabled(!hasChanges && !isNew)
            }
            .font(.callout)
            .padding(12)
        }
        // Pick up the automatic sorting when it finishes, unless the user has started editing.
        .onChange(of: stored) { _, latest in
            if let latest, !userEdited { record = latest }
        }
    }

    /// A binding that marks the draft as edited by the user.
    private func edit<T>(_ keyPath: WritableKeyPath<DocumentRecord, T>) -> Binding<T> {
        Binding(get: { record[keyPath: keyPath] }, set: { record[keyPath: keyPath] = $0; userEdited = true; justSaved = false })
    }

    private func save() {
        // Saving confirms the details, including an automatic type.
        model.documents.update(record)
        userEdited = true
        withAnimation { justSaved = true }
    }
}
