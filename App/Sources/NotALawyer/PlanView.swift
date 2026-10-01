import NotALawyerCore
import QuickLook
import SwiftUI

/// A plan towards a goal: the law's conditions and the usual steps, ticked off by the user.
/// Each item shows the paragraph it comes from. The app never ticks anything itself.
struct PlanView: View {
    @Environment(AppModel.self) private var model
    let plan: Plan
    @State private var previewURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                MarginRow {
                    Text("\(done)/\(plan.steps.count)")
                        .font(Theme.margin(40, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.stamp)
                        .monospacedDigit()
                        .accessibilityLabel("\(done) of \(plan.steps.count) ticked")
                } content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Headline(text: plan.german)
                        Text(plan.summary).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("Tick what you think you've done or have. This is your own checklist; only the authority decides whether a condition is met.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(plan.steps) { step in
                    PlanStepRow(plan: plan, step: step, previewURL: $previewURL)
                }

                MarginRow { EmptyView() } content: { WhereToAskView() }
                Color.clear.frame(height: 30)
            }
            .frame(maxWidth: Theme.pageWidth)
            .padding(.horizontal, 32)
            .padding(.top, 36)
            .frame(maxWidth: .infinity)
        }
        .background(PageBackground())
        .navigationTitle(plan.title)
        .quickLookPreview($previewURL)
    }

    private var done: Int { plan.steps.filter { model.isDone($0, in: plan) }.count }
}

struct PlanStepRow: View {
    @Environment(AppModel.self) private var model
    let plan: Plan
    let step: PlanStep
    @Binding var previewURL: URL?
    @State private var showLaw = false
    @State private var askingProof = false

    var body: some View {
        let done = model.isDone(step, in: plan)
        MarginRow {
            Button {
                if done { model.setDone(false, step, in: plan) } else { askingProof = true }
            } label: {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(done ? Theme.stamp : .secondary)
            }
            .buttonStyle(.plain)
            .help(done ? "Untick, and remove your proof" : "Tick off, with your proof")
            .accessibilityLabel(done ? "Ticked: \(step.title)" : "Not ticked: \(step.title)")
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.german).font(Theme.serif(.body)).italic().foregroundStyle(.secondary)
                if !step.detail.isEmpty {
                    Text(step.detail).fixedSize(horizontal: false, vertical: true)
                }

                let others = Plan.sameCondition(as: step).filter { $0.plan.id != plan.id }
                if !others.isEmpty {
                    Label("Same condition in: \(others.map(\.plan.title).joined(separator: ", ")). Ticking it here ticks it there too.",
                          systemImage: "link")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let proof = model.proof(for: step, in: plan) {
                    ProofSummary(proof: proof, previewURL: $previewURL)
                } else {
                    let documents = model.documents.records.filter { step.documentKinds.contains($0.kind.rawValue) }
                    if !documents.isEmpty {
                        HStack(spacing: 8) {
                            Text("You have:").font(.callout).foregroundStyle(.secondary)
                            ForEach(documents) { record in
                                Button { previewURL = model.documents.fileURL(for: record) } label: {
                                    Label(record.title, systemImage: record.kind.systemImage).lineLimit(1)
                                }
                                .buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                    }
                }

                HStack(spacing: 14) {
                    Button { model.explain(step, in: plan) } label: { Label("What does this mean?", systemImage: "questionmark.bubble") }
                        .buttonStyle(.link)
                    if !done {
                        Button { askingProof = true } label: {
                            step.kind == .action
                                ? Label("Mark as done", systemImage: "checkmark.circle")
                                : Label("I meet this", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.link)
                    }
                }
                .font(.callout)

                DisclosureGroup(isExpanded: $showLaw) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(step.refs, id: \.self) { ref in
                            if let section = model.index?.section(law: ref.law, number: ref.section) {
                                let paragraphs = section.paragraphs.filter { ref.paragraph == nil || $0.number == ref.paragraph }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(ref.label).font(Theme.margin(17, relativeTo: .headline)).foregroundStyle(Theme.stamp)
                                        Text(section.displayHeading).font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Link("Official text", destination: section.sourceURL).font(.caption)
                                    }
                                    ForEach(paragraphs, id: \.self) { p in
                                        Text(p.text).font(Theme.serif(.callout)).lineSpacing(3).textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("What the law says: \(step.refs.map(\.label).joined(separator: ", "))").font(.callout)
                }
            }
        }
        .sheet(isPresented: $askingProof) {
            ProofSheet(plan: plan, step: step)
        }
    }
}

/// "How do you know?" Ticking a plan item needs support: one of your documents, a reason, or both.
struct ProofSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let plan: Plan
    let step: PlanStep
    @State private var proof = StepProof()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.kind == .action ? "When did you do it?" : "How do you know?").font(Theme.serif(.title, weight: .semibold))
            Text(step.title).font(.headline)
            Text(step.kind == .action
                 ? "Note when and how you did this, for example the date you applied and any file number (Aktenzeichen) you got. Attach the confirmation if you have one."
                 : "Tick this off with something that supports it: a document you have, a reason in your own words, or both. You'll need the same proof for the authority.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            let relevant = model.documents.records.filter { step.documentKinds.contains($0.kind.rawValue) }
            let others = model.documents.records.filter { !step.documentKinds.contains($0.kind.rawValue) }
            GroupBox("Your documents") {
                if model.documents.records.isEmpty {
                    HStack {
                        Text("No documents yet.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Add a document…") {
                            dismiss()
                            model.sidebarSelection = .documents
                            model.importingDocument = true
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(relevant + others) { record in
                                Toggle(isOn: Binding(
                                    get: { proof.documentIDs.contains(record.id) },
                                    set: { if $0 { proof.documentIDs.append(record.id) } else { proof.documentIDs.removeAll { $0 == record.id } } }
                                )) {
                                    HStack {
                                        Label(record.title, systemImage: record.kind.systemImage)
                                        if relevant.contains(record) {
                                            Text("usually shows this").font(.caption).foregroundStyle(Theme.stamp)
                                        }
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
            }

            let earlier = model.otherProofs(excluding: step, in: plan)
            if !earlier.isEmpty && step.kind == .condition {
                GroupBox("Proof you've already given") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(earlier.prefix(6).enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.callout.weight(.semibold))
                                        Text(summary(item.proof)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                        Text("in \(item.plan)").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Use this") {
                                        proof.documentIDs = Array(Set(proof.documentIDs + item.proof.documentIDs))
                                        if proof.note.isEmpty { proof.note = item.proof.note }
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.kind == .action ? "What you did" : "Your reason").font(.headline)
                TextField(step.kind == .action
                          ? "e.g. Applied online on 3 March 2026, file number 123-456"
                          : "e.g. Registered in Berlin since March 2021, with a residence permit the whole time",
                          text: $proof.note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(step.kind == .action ? "Mark as done" : "Tick off with this proof") {
                    proof.date = Date()
                    model.setDone(true, step, in: plan, proof: proof)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(proof.isEmpty)
            }
            if proof.isEmpty {
                Text(step.kind == .action ? "Write what you did, or attach a confirmation." : "Choose a document or write a reason to tick this off.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 540)
        .onAppear { if let existing = model.proof(for: step, in: plan) { proof = existing } }
    }

    private func summary(_ proof: StepProof) -> String {
        let docs = model.documents.records.filter { proof.documentIDs.contains($0.id) }.map(\.title)
        return (docs + (proof.note.isEmpty ? [] : ["“\(proof.note)”"])).joined(separator: " · ")
    }
}

struct ProofSummary: View {
    @Environment(AppModel.self) private var model
    let proof: StepProof
    @Binding var previewURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Your note", systemImage: "checkmark.seal.fill").font(.callout.weight(.semibold)).foregroundStyle(Theme.stamp)
            let documents = model.documents.records.filter { proof.documentIDs.contains($0.id) }
            if !documents.isEmpty {
                HStack(spacing: 8) {
                    ForEach(documents) { record in
                        Button { previewURL = model.documents.fileURL(for: record) } label: {
                            Label(record.title, systemImage: record.kind.systemImage).lineLimit(1)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
            if proof.documentIDs.count > documents.count {
                Text("A document you attached has since been deleted.").font(.caption).foregroundStyle(Theme.amber)
            }
            if !proof.note.isEmpty {
                Text("“\(proof.note)”").italic().fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.stamp.opacity(0.07)))
    }
}
