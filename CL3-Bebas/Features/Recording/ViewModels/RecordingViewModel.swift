import Foundation
import AVFoundation
import Combine

// MARK: - Language Model

enum PitchLanguage: String, CaseIterable, Identifiable {
    case english         = "English"
    case bahasaIndonesia = "Bahasa Indonesia"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:         return Locale(identifier: "en-US")
        case .bahasaIndonesia: return Locale(identifier: "id-ID")
        }
    }
}

// MARK: - Page Enum
enum RecordPitchPage { case languageSelection, recording, analyzing }

// MARK: - ViewModel
@MainActor
final class RecordPitchViewModel: ObservableObject {

    // MARK: Published
    @Published var currentPage:      RecordPitchPage = .languageSelection
    @Published var selectedLanguage: PitchLanguage   = .english
    @Published var isRecording:      Bool  = false
    @Published var isPaused:         Bool  = false
    @Published var elapsedSeconds:   Int   = 0
    @Published var micLevel:         Float = 0.0
    @Published var waveformBars:     [Float]
    @Published var permissionDenied: Bool  = false
    @Published var isConfirmed:      Bool  = false
    @Published var recordingTitle: String = "Title Recording 1"

    // Alert states for the new UI
    @Published var showReRecordAlert:  Bool = false
    @Published var showFinishAlert:    Bool = false
    @Published var showTimeLimitAlert: Bool = false

    /// Set once `confirmRecording()` stops the underlying AudioRecorder.
    /// Carries the captured amplitude/pitch samples + file URL for
    /// whatever eventually builds the pace / articulation / intonation
    /// analysis on the Review Summary screen.
    @Published private(set) var lastSample: AudioSampleData?

    // MARK: Private
    /// The real recording engine — AVAudioEngine based, lives in
    /// AudioRecorder.swift. The ViewModel just drives it and mirrors
    /// what the existing UI needs into the @Published properties above.
    private let audioRecorder: AudioRecorder

    private var clockCancellable: AnyCancellable?
    private var levelCancellable: AnyCancellable?   // preview-only ticker
    private var bindings = Set<AnyCancellable>()
    private let maxSeconds = 300

    /// When true the ViewModel never touches AVFoundation / AudioRecorder —
    /// safe to use in Xcode Previews.
    let isPreview: Bool

    // MARK: - Init
    @MainActor
    init(isPreview: Bool = false, audioRecorder: AudioRecorder? = nil) {
        self.isPreview     = isPreview
        self.audioRecorder = audioRecorder ?? AudioRecorder()
        self.waveformBars  = Self.makeFlatBars()

        if !isPreview {
            bindAudioRecorder()
        }
    }

    // MARK: - Computed
    var formattedTime: String {
        String(format: "%02d : %02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    // MARK: - Navigation
    func confirmLanguageSelection() {
        currentPage = .recording
        // Do NOT auto-start recording here.
        // The user must tap the mic button on the RecordingView.
    }

    /// Called by the UI when the user taps the mic / record button.
    func beginRecordingSession() {
        if isPreview {
            startPreviewPlayback()
        } else {
            Task { await requestPermissionAndRecord() }
        }
    }

    /// Re-record: stop current, reset to idle (mic button) state.
    func reRecord() {
        if isPreview {
            cancelPreviewTimers()
        } else {
            _ = audioRecorder.stopRecording()
            audioRecorder.reset()
            cancelClock()
        }
        isRecording    = false
        isPaused       = false
        elapsedSeconds = 0
        waveformBars   = Self.makeFlatBars()
    }

    /// Called when the user confirms finishing (from alert).
    func finishRecording() {
        confirmRecording()
    }

    func goBack() {
        guard currentPage == .recording else { return }
        teardown()
        elapsedSeconds = 0
        waveformBars   = Self.makeFlatBars()
        currentPage = .languageSelection
    }

    func confirmRecording() {
        if isPreview {
            cancelPreviewTimers()
        } else {
            lastSample = audioRecorder.stopRecording()
            cancelClock()
        }
        isRecording = false
        isPaused    = false
        isConfirmed = true
    }

    // MARK: - Pause / Resume
    func togglePauseResume() {
        if isPreview {
            isPaused.toggle()
            isPaused ? cancelPreviewTimers() : startPreviewPlayback()
            return
        }
        guard isRecording else { return }
        if isPaused {
            audioRecorder.resumeRecording()
            isPaused = false
            startClock()
        } else {
            audioRecorder.pauseRecording()
            isPaused = true
            cancelClock()
        }
    }

    // MARK: - Real recording (AudioRecorder-backed)
    private func requestPermissionAndRecord() async {
        let granted = await requestMicPermission()
        guard granted else {
            permissionDenied = true
            return
        }
        audioRecorder.startRecording()
        isRecording    = true
        isPaused       = false
        elapsedSeconds = 0
        startClock()
    }

    /// Mirrors AudioRecorder's own permission switch so the ViewModel
    /// can surface `permissionDenied` to the UI — AudioRecorder's
    /// `startRecording()` swallows a denial silently.
    private func requestMicPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    /// Mirrors AudioRecorder's live amplitude into the waveform the
    /// existing RecordingView renders. AudioRecorder only emits while
    /// its AVAudioEngine is actually running, so this naturally goes
    /// quiet — and the waveform freezes — while paused.
    private func bindAudioRecorder() {
        audioRecorder.$currentAmplitude
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rms in
                guard let self, self.isRecording, !self.isPaused else { return }
                let level = Self.normalizedLevel(fromRMS: rms)
                self.micLevel = level
                self.pushBar(level)
            }
            .store(in: &bindings)
    }

    private func teardown() {
        if isPreview {
            cancelPreviewTimers()
        } else {
            _ = audioRecorder.stopRecording()
            cancelClock()
        }
        isRecording = false
        isPaused    = false
    }

    // MARK: - Clock (elapsed seconds — real recording)
    private func startClock() {
        clockCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= self.maxSeconds {
                    self.cancelClock()
                    if !self.isPreview {
                        self.audioRecorder.pauseRecording()
                    }
                    self.isPaused = true
                    self.showTimeLimitAlert = true
                }
            }
    }

    private func cancelClock() {
        clockCancellable?.cancel()
        clockCancellable = nil
    }

    // MARK: - Preview simulation (unchanged — no AVFoundation)
    private func startPreviewPlayback() {
        isRecording = true
        isPaused    = false
        clockCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= self.maxSeconds {
                    self.cancelPreviewTimers()
                    self.showTimeLimitAlert = true
                }
            }
        levelCancellable = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickPreview() }
    }

    private func cancelPreviewTimers() {
        clockCancellable?.cancel(); clockCancellable = nil
        levelCancellable?.cancel(); levelCancellable = nil
    }

    private func tickPreview() {
        let speaking = Float.random(in: 0...1) > 0.25
        let base:  Float = speaking ? Float.random(in: 0.35...0.80) : Float.random(in: 0.04...0.15)
        let spike: Float = speaking && Bool.random() ? Float.random(in: 0...0.20) : 0
        let level  = min(1.0, base + spike)
        micLevel   = level
        pushBar(level)
    }

    // MARK: - Shared bar-push logic
    private func pushBar(_ amplitude: Float) {
        var bars = waveformBars
        bars.removeFirst()
        let noise = Float.random(in: -0.06...0.06)
        bars.append(max(0.04, min(1.0, amplitude + noise)))
        waveformBars = bars
    }

    // MARK: - Level mapping
    /// AudioRecorder publishes raw RMS amplitude (linear, ~0...1).
    /// Convert to dB and normalize the same way the previous
    /// AVAudioRecorder-based meter did, so the waveform "feel" matches.
    private static func normalizedLevel(fromRMS rms: Float) -> Float {
        guard rms > 0 else { return 0.04 }
        let db   = 20 * log10(rms)
        let norm = (db + 55.0) / 55.0
        return max(0.04, min(1.0, norm))
    }

    // MARK: - Static helpers
    static func makeFlatBars() -> [Float] {
        (0..<60).map { _ in Float.random(in: 0.04...0.10) }
    }
}
