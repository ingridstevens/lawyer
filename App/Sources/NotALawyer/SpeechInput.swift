import AVFoundation
import Observation
import Speech

/// Dictation for questions, on this Mac only.
///
/// Uses Apple's speech recogniser with `requiresOnDeviceRecognition`, so audio never goes to
/// Apple's servers. If the Mac has no on-device model for the language, it says so instead of
/// falling back to the server.
@MainActor @Observable
final class SpeechInput {
    enum State: Equatable {
        case idle
        case listening
        case unavailable(String)
    }

    private(set) var state: State = .idle
    /// What's been recognised so far in this session.
    private(set) var transcript = ""
    /// Called with the latest transcript while listening.
    var onText: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    var isListening: Bool { state == .listening }

    func toggle(languageCode: String) {
        if isListening { stop() } else { Task { await start(languageCode: languageCode) } }
    }

    func start(languageCode: String) async {
        guard await authorised() else {
            state = .unavailable("Not a Lawyer needs permission to use the microphone and speech recognition. Allow it in System Settings → Privacy & Security.")
            return
        }
        let locale = Self.speechLocale(for: languageCode)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            state = .unavailable("Speech recognition isn't available for \(Self.name(locale)) on this Mac.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            state = .unavailable("This Mac has no on-device speech model for \(Self.name(locale)), and the app won't send your voice to a server. To add one, turn on Dictation for \(Self.name(locale)) in System Settings → Keyboard → Dictation, then try again.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(request))
        do {
            engine.prepare()
            try engine.start()
        } catch {
            state = .unavailable("The microphone couldn't start: \(error.localizedDescription)")
            return
        }

        transcript = ""
        state = .listening
        armSilenceTimer()
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler { [weak self] text, isFinal, failed in
            guard let self else { return }
            if let text {
                self.transcript = text
                self.onText?(text)
                self.armSilenceTimer()
                if isFinal { self.stop() }
            }
            if failed, self.isListening { self.stop() }
        })
    }

    // Audio and recognition callbacks run on background threads. Building them in nonisolated
    // functions keeps them from inheriting main-actor isolation, which would crash at runtime.

    nonisolated private static func tapBlock(_ request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    nonisolated private static func resultHandler(
        _ deliver: @escaping @MainActor (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in deliver(text, isFinal, failed) }
        }
    }

    func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        if state == .listening { state = .idle }
    }

    func dismissMessage() { if case .unavailable = state { state = .idle } }

    /// Stops after a pause, like dictation does.
    private func armSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false, block: Self.timerBlock { [weak self] in
            if let self, !self.transcript.isEmpty { self.stop() }
        })
    }

    nonisolated private static func timerBlock(_ fire: @escaping @MainActor () -> Void) -> @Sendable (Timer) -> Void {
        { _ in Task { @MainActor in fire() } }
    }

    private func authorised() async -> Bool {
        let speech = await Self.requestSpeechAuthorization()
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        return speech && mic
    }

    nonisolated private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }

    /// The app stores a language ("tr"); the recogniser needs a region too ("tr-TR").
    static func speechLocale(for code: String) -> Locale {
        let preferred: [String: String] = ["en": "en-US", "de": "de-DE", "tr": "tr-TR", "uk": "uk-UA", "ru": "ru-RU",
                                           "ar": "ar-SA", "es": "es-ES", "fr": "fr-FR", "it": "it-IT", "pl": "pl-PL",
                                           "pt": "pt-PT", "zh": "zh-CN", "vi": "vi-VN", "hi": "hi-IN", "ro": "ro-RO", "fa": "fa-IR"]
        let id = preferred[code] ?? SFSpeechRecognizer.supportedLocales().first { $0.language.languageCode?.identifier == code }?.identifier ?? "en-US"
        return Locale(identifier: id)
    }

    static func name(_ locale: Locale) -> String {
        Locale(identifier: "en").localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }
}
