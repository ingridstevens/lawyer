import Foundation
import NotALawyerApple
import NotALawyerCore
import SwiftUI

/// What this Mac can run.
struct MacHardware {
    let chip: String
    let memoryGB: Double
    let freeDiskGB: Double
    /// Approximate memory bandwidth, which sets how fast a model writes once loaded.
    let bandwidthGBs: Double

    static let current: MacHardware = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        let chip = String(cString: buffer)
        let memory = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let free = (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage.map { Double($0) / 1e9 } ?? 0
        return MacHardware(chip: chip, memoryGB: memory, freeDiskGB: free, bandwidthGBs: bandwidth(for: chip))
    }()

    /// Published unified-memory bandwidth per chip, in GB/s. Unknown chips get a cautious guess.
    static func bandwidth(for chip: String) -> Double {
        let c = chip.lowercased()
        let tier = c.contains("ultra") ? "ultra" : c.contains("max") ? "max" : c.contains("pro") ? "pro" : "base"
        let gen = ["m5", "m4", "m3", "m2", "m1"].first { c.contains($0) } ?? "m1"
        let table: [String: [String: Double]] = [
            "m1": ["base": 68, "pro": 200, "max": 400, "ultra": 800],
            "m2": ["base": 100, "pro": 200, "max": 400, "ultra": 800],
            "m3": ["base": 100, "pro": 150, "max": 300, "ultra": 800],
            "m4": ["base": 120, "pro": 273, "max": 410, "ultra": 800],
            "m5": ["base": 153, "pro": 300, "max": 500, "ultra": 800],
        ]
        return table[gen]?[tier] ?? 68
    }
}

/// A model the advisor knows about. Sizes are Ollama's download sizes (checked October 2026).
struct ModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let sizeGB: Double
    let note: String
    /// Higher is better at this task, until our own evaluation results replace these guesses.
    let quality: Int
    var isNew = false

    static let catalog: [ModelOption] = [
        ModelOption(id: "qwen3.8:27b", name: "Qwen 3.8 27B", sizeGB: 17.7, note: "New. Alibaba's latest; likely the strongest here, but slow on most laptops.", quality: 10, isNew: true),
        ModelOption(id: "ministral-3:14b", name: "Ministral 3 14B", sizeGB: 9.1, note: "Mistral. Strong in German and other European languages.", quality: 7),
        ModelOption(id: "granite4.2:8b", name: "Granite 4.2 8B", sizeGB: 5.3, note: "New. IBM, built for answering from documents (RAG), JSON output and many languages including German. Try this first on 16 GB+.", quality: 7, isNew: true),
        ModelOption(id: "granite4.2:3b", name: "Granite 4.2 3B", sizeGB: 2.2, note: "New. Tiny version of the above, for 8 GB Macs.", quality: 3, isNew: true),
        ModelOption(id: "gemma4:31b", name: "Gemma 4 31B", sizeGB: 20.4, note: "Google. The strongest here at German and other languages, if you have the memory.", quality: 9),
        ModelOption(id: "qwen3.5:27b", name: "Qwen 3.5 27B", sizeGB: 17.4, note: "Alibaba. Very capable, good at following the citation format.", quality: 8),
        ModelOption(id: "gemma4:26b", name: "Gemma 4 26B", sizeGB: 18.7, note: "Google. Mixture-of-experts, so faster than its size suggests.", quality: 8),
        ModelOption(id: "gemma4:12b", name: "Gemma 4 12B", sizeGB: 8.0, note: "Google. Good German and many other languages. A strong all-rounder.", quality: 7),
        ModelOption(id: "qwen3.5:9b", name: "Qwen 3.5 9B", sizeGB: 6.6, note: "Alibaba. Good structured output; a little weaker in rarer languages.", quality: 6),
        ModelOption(id: "gemma4:e4b", name: "Gemma 4 E4B", sizeGB: 6.6, note: "Google. Built for laptops; good languages for its size.", quality: 5),
        ModelOption(id: "qwen3.5:4b", name: "Qwen 3.5 4B", sizeGB: 3.4, note: "Small and fast. Fine for simple questions.", quality: 4),
        ModelOption(id: "qwen3.5:2b", name: "Qwen 3.5 2B", sizeGB: 2.7, note: "Very small. Only for Macs with 8 GB.", quality: 2),
    ]
}

/// How a model fits a Mac. The model plus its working memory (~2 GB at our context size) has
/// to fit next to macOS and your other apps.
enum Fit: Comparable {
    case good, tight, tooBig

    static func of(_ m: ModelOption, on hw: MacHardware) -> Fit {
        let need = m.sizeGB + 2
        if need <= hw.memoryGB * 0.6 { return .good }
        if need <= hw.memoryGB * 0.75 { return .tight }
        return .tooBig
    }
}

/// Estimated time for one answer on this Mac.
///
/// A model writes roughly (memory bandwidth ÷ model size) words per second, because every word
/// it writes reads the whole model from memory once. An answer is about 400 tokens out, after
/// reading about 4,000 tokens of law, which goes roughly 8 times faster than writing.
enum Speed {
    case fast, fine, slow

    static func seconds(_ m: ModelOption, on hw: MacHardware) -> Double {
        let tokensPerSecond = hw.bandwidthGBs * 0.6 / m.sizeGB
        return 400 / tokensPerSecond + 4_000 / (tokensPerSecond * 8)
    }

    static func of(_ m: ModelOption, on hw: MacHardware) -> Speed {
        let s = seconds(m, on: hw)
        return s <= 40 ? .fast : s <= 120 ? .fine : .slow
    }

    static func label(_ m: ModelOption, on hw: MacHardware) -> String {
        let s = seconds(m, on: hw)
        if s < 60 { return "about \(Int((s / 5).rounded()) * 5) seconds per answer" }
        return "about \(Int((s / 60).rounded())) minute\(s >= 90 ? "s" : "") per answer"
    }
}

enum ModelAdvisor {
    /// The best model that fits comfortably and isn't slow; failing that, the best that fits at all.
    static func recommended(on hw: MacHardware) -> ModelOption? {
        let ranked = ModelOption.catalog.sorted { $0.quality > $1.quality }
        return ranked.first { Fit.of($0, on: hw) == .good && Speed.of($0, on: hw) != .slow && $0.sizeGB < hw.freeDiskGB - 2 }
            ?? ranked.first { Fit.of($0, on: hw) != .tooBig && $0.sizeGB < hw.freeDiskGB - 2 }
    }

    static func summary(on hw: MacHardware) -> String {
        if hw.memoryGB < 12 {
            return "With \(Int(hw.memoryGB.rounded())) GB of memory, Apple's on-device model is the best choice: it's built in and uses no extra memory. A tiny local model is possible but answers less well."
        }
        if let best = recommended(on: hw) {
            return "With \(Int(hw.memoryGB.rounded())) GB of memory on an \(hw.chip), \(best.name) fits comfortably and is the best choice here. Apple's on-device model also works and is quickest to start, but it reads fewer law passages per answer."
        }
        return "Apple's on-device model is the best choice for this Mac."
    }
}

// MARK: View

/// Recommends and downloads local models through Ollama.
struct ModelAdvisorView: View {
    @Environment(AppModel.self) private var model
    let hardware = MacHardware.current
    @State private var ollamaVersion: String?
    @State private var checkedOllama = false
    @State private var installed: Set<String> = []
    @State private var downloading: [String: Double] = [:]
    @State private var downloadError: String?

    var body: some View {
        Section {
            if !checkedOllama {
                ProgressView().controlSize(.small)
            } else if ollamaVersion == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local models run in Ollama, a free app. Ollama isn't running on this Mac.")
                    HStack {
                        Link("Get Ollama", destination: URL(string: "https://ollama.com/download/mac")!)
                        Button("Check again") { Task { await refresh() } }
                    }
                    Text("Install it, open it once, then check again.").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ForEach(ModelOption.catalog) { option in
                    row(option)
                }
                if let downloadError {
                    Label(downloadError, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption)
                }
            }
        } header: {
            Text("Models for Ollama")
        } footer: {
            Text("Downloads come from ollama.com through Ollama, not through this app. Rankings are estimates until the evaluation results are in.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task { await refresh() }
    }

    private func row(_ option: ModelOption) -> some View {
        let fit = Fit.of(option, on: hardware)
        let isRecommended = option.id == ModelAdvisor.recommended(on: hardware)?.id
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(option.name).fontWeight(.semibold)
                    if option.isNew {
                        Text("New").font(.caption.weight(.semibold)).foregroundStyle(Theme.stamp)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().stroke(Theme.stamp))
                    }
                    if isRecommended {
                        Text("Recommended").font(.caption.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Theme.stamp))
                    }
                }
                Text(option.note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("\(String(format: "%.1f", option.sizeGB)) GB download. \(fitLabel(fit)). \(speedText(option))")
                    .font(.caption).foregroundStyle(fit == .tooBig ? Theme.amber : .secondary)
                    .help("Estimated from this Mac's memory bandwidth and the model's size. After you've used a model, this shows your measured average instead.")
            }
            Spacer()
            action(option, fit: fit)
        }
        .opacity(fit == .tooBig ? 0.55 : 1)
    }

    @ViewBuilder private func action(_ option: ModelOption, fit: Fit) -> some View {
        if let progress = downloading[option.id] {
            ProgressView(value: progress).frame(width: 90)
        } else if installed.contains(option.id) {
            if isActive(option) {
                Label("In use", systemImage: "checkmark").foregroundStyle(Theme.stamp)
            } else {
                Button("Use") {
                    model.settings.provider = .localServer(kind: .ollama, baseURL: LocalServerProvider.Kind.ollama.defaultBaseURL, model: option.id)
                }
            }
        } else {
            Button("Download") { Task { await download(option) } }
                .disabled(fit == .tooBig || option.sizeGB > hardware.freeDiskGB - 2)
                .help(option.sizeGB > hardware.freeDiskGB - 2 ? "Not enough free disk space" : "Download \(option.name) with Ollama")
        }
    }

    private func speedText(_ option: ModelOption) -> String {
        if let times = model.settings.answerTimes[option.id], !times.isEmpty {
            let average = times.reduce(0, +) / Double(times.count)
            return "Measured: about \(Int(average.rounded())) seconds per answer."
        }
        let label = Speed.label(option, on: hardware)
        return "Estimated: " + label + "."
    }

    private func fitLabel(_ fit: Fit) -> String {
        switch fit {
        case .good: "Fits well"
        case .tight: "Fits, but close other apps"
        case .tooBig: "Too big for this Mac"
        }
    }

    private func isActive(_ option: ModelOption) -> Bool {
        if case let .localServer(_, _, name) = model.settings.provider { return name == option.id }
        return false
    }

    private func refresh() async {
        ollamaVersion = await LocalServerProvider.ollamaVersion()
        checkedOllama = true
        if ollamaVersion != nil {
            installed = Set((try? await LocalServerProvider.availableModels(kind: .ollama)) ?? [])
        }
    }

    private func download(_ option: ModelOption) async {
        downloadError = nil
        downloading[option.id] = 0
        do {
            try await LocalServerProvider.pullOllamaModel(option.id) { fraction, _ in
                Task { @MainActor in if let fraction { downloading[option.id] = fraction } }
            }
            downloading[option.id] = nil
            await refresh()
        } catch {
            downloading[option.id] = nil
            downloadError = "Couldn't download \(option.name): \(error.localizedDescription)"
        }
    }
}

/// What this Mac can run, and the advisor's recommendation.
struct HardwareSummary: View {
    let hardware = MacHardware.current

    var body: some View {
        Section {
            LabeledContent("This Mac", value: "\(hardware.chip), \(Int(hardware.memoryGB.rounded())) GB memory, \(Int(hardware.freeDiskGB)) GB free")
            Text(ModelAdvisor.summary(on: hardware)).font(.callout).fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("What this Mac can run")
        }
    }
}
