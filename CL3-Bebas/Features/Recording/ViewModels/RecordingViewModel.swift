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
enum RecordPitchPage { case languageSelection, recording }

// MARK: - ViewModel
@MainActor
final class RecordPitchViewModel: NSObject, ObservableObject {

    // MARK: Published
    @Published var currentPage:   RecordPitchPage = .languageSelection
    @Published var selectedLanguage: PitchLanguage = .english
    @Published var isRecording:   Bool  = false
    @Published var isPaused:      Bool  = false
    @Published var elapsedSeconds: Int  = 0
    @Published var micLevel:      Float = 0.0
    @Published var waveformBars: [Float]
    @Published var permissionDenied: Bool = false
    @Published var isConfirmed:   Bool  = false

    // MARK: Private
    private var audioRecorder: AVAudioRecorder?
    private var clockCancellable: AnyCancellable?
    private var levelCancellable: AnyCancellable?
    private let maxSeconds = 300

    /// When true the ViewModel never touches AVFoundation —
    /// safe to use in Xcode Previews.
    let isPreview: Bool

    // MARK: - Init
    init(isPreview: Bool = false) {
        self.isPreview  = isPreview
        self.waveformBars = Self.makeFlatBars()   // safe default; no AVFoundation
        super.init()
    }

    // MARK: - Computed
    var formattedTime: String {
        String(format: "%02d : %02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    // MARK: - Navigation
    func confirmLanguageSelection() {
        currentPage = .recording
        if isPreview {
            startPreviewPlayback()
        } else {
            Task { await requestPermissionAndRecord() }
        }
    }

    func goBack() {
        guard currentPage == .recording else { return }
        teardown()
        currentPage = .languageSelection
    }

    func confirmRecording() {
        teardown()
        isConfirmed = true
    }

    // MARK: - Pause / Resume
    func togglePauseResume() {
        if isPreview {
            isPaused.toggle()
            isPaused ? cancelTimers() : startPreviewPlayback()
            return
        }
        guard let rec = audioRecorder else { return }
        if isPaused {
            rec.record()
            isPaused = false
            startTimers(useMeter: true)
        } else {
            rec.pause()
            isPaused = true
            cancelTimers()
        }
    }

    // MARK: - Real AVFoundation
    private func requestPermissionAndRecord() async {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission {
                    cont.resume(returning: $0)
                }
            }
        }
        granted ? beginRecording() : (permissionDenied = true)
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("pitch_\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey:          44100,
                AVNumberOfChannelsKey:    1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording    = true
            isPaused       = false
            elapsedSeconds = 0
            startTimers(useMeter: true)
        } catch {
            print("Recording error: \(error)")
        }
    }

    private func teardown() {
        audioRecorder?.stop()
        audioRecorder = nil
        cancelTimers()
        isRecording = false
        isPaused    = false
    }

    // MARK: - Timers
    private func startTimers(useMeter: Bool) {
        // 1-second clock
        clockCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= self.maxSeconds { self.teardown() }
            }

        // ~30 fps level / waveform update
        levelCancellable = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if useMeter { self.sampleMeter() } else { self.tickPreview() }
            }
    }

    private func cancelTimers() {
        clockCancellable?.cancel(); clockCancellable = nil
        levelCancellable?.cancel(); levelCancellable = nil
    }

    // MARK: - AVFoundation metering
    private func sampleMeter() {
        guard let rec = audioRecorder, rec.isRecording else {
            // Decay smoothly when not recording
            waveformBars = waveformBars.map { max(0.04, $0 * 0.80) }
            micLevel     = max(0, micLevel * 0.80)
            return
        }
        rec.updateMeters()

        // Map dB (-60…0) → 0…1, boosted so a quiet voice reads ~0.4–0.6
        let db   = rec.averagePower(forChannel: 0)
        let norm = max(0.0, min(1.0, (db + 55.0) / 55.0))
        micLevel = norm

        pushBar(norm)
    }

    // MARK: - Preview simulation
    private func startPreviewPlayback() {
        isRecording = true
        isPaused    = false
        startTimers(useMeter: false)
    }

    private func tickPreview() {
        // Simulate a person speaking: bursts + silences
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

    // MARK: - Static helpers
    static func makeFlatBars() -> [Float] {
        // Low, uneven idle state — looks like silence on a real recorder
        (0..<60).map { _ in Float.random(in: 0.04...0.10) }
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordPitchViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully _: Bool) {
        Task { @MainActor in isRecording = false }
    }
}
