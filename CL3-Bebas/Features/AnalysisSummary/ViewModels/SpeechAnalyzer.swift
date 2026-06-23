//
//  SpeechAnalyzer.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import Foundation
@preconcurrency import Speech
import Combine
import AVFoundation

// MARK: - Analysis Result

struct AnalysisResult {
    /// Stable identifier of the persisted `RecordingHistoryModel`
    /// row this result was built from, if any.
    ///
    /// `nil` for ephemeral results (e.g. the live analysis produced
    /// by the recording flow before it is saved). Set when the
    /// result is re-hydrated from a SwiftData row (e.g. when the
    /// user taps a History row) so downstream screens like
    /// `ReviewSummaryView` can look the row back up and persist
    /// edits (e.g. title changes) back to SwiftData.
    var id: UUID?

    var transcription: String
    var duration: TimeInterval
    var wordsPerMinute: Double
    var paceLabel: String
    var averageAmplitudeDB: Float
    var volumeLabel: String
    var pitchSamples: [Float]
    var pitchVariance: Float
    var intonationLabel: String
    var amplitudeSamples: [Float]
    var articulationScore: Float
    var pronunciationIssues: [PronunciationIssue]
    var audioFileURL: URL?
    var intonationHighlight: AudioHighlightSegment?
    var paceHighlight: AudioHighlightSegment?
    
    var overallScore: Float {
            let paceScore: Float = {
                switch paceLabel {
                case "Ideal": return 1.0
                case "Normal": return 0.85
                case "Fast", "Slow": return 0.65
                case "Too Fast", "Too Slow": return 0.35
                default: return 0.5
                }
            }()

            let intonationScore: Float =
                intonationLabel == "Varied" ? 1.0 : 0.5

            return articulationScore * 0.4
                 + paceScore * 0.3
                 + intonationScore * 0.3
        }

    
}

extension AnalysisResult: Hashable {
    static func == (lhs: AnalysisResult, rhs: AnalysisResult) -> Bool {
        lhs.audioFileURL == rhs.audioFileURL &&
        lhs.transcription == rhs.transcription &&
        lhs.duration == rhs.duration
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(audioFileURL)
        hasher.combine(transcription)
        hasher.combine(duration)
    }
}

// MARK: - SpeechAnalyzer

@MainActor
class SpeechAnalyzer: ObservableObject {

    @Published var isAnalyzing = false
    @Published var progress: Double = 0
    @Published var liveTranscription: String = ""
    @Published var isModelReady: Bool = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    var liveRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Phoneme model — init is now cheap (no MLModel load); loading
    /// is deferred to warmup() which runs on a background thread.
    private let phonemeRunner = PhonemeModelRunner()

    /// Acoustic-path (Wav2Vec2 CTC) runner. Created in `init`, but the
    /// underlying MLModel is loaded lazily on `warmup()` so init stays
    /// cheap. Picks the EN/ID bundle based on `languageCode` at the
    /// point of the first `analyze(...)` call.
    private let acousticEN = Wav2Vec2AcousticRunner(
        modelName: "Wav2Vec2_EN",
        vocabResource: "wav2vec2_vocab_en"
    )
    private let acousticID = Wav2Vec2AcousticRunner(
        modelName: "Wav2Vec2_ID",
        vocabResource: "wav2vec2_vocab_id"
    )
    private var acousticRunner: Wav2Vec2AcousticRunner {
        languageCode == "en" ? acousticEN : acousticID
    }

    /// One-shot guard so `warmup()` is safe to call from multiple sites
    /// (e.g. `init`, `analyze`, external caller). `warmup()` itself
    /// fires off background MLModel loads that are themselves
    /// idempotent, but we don't want to spam the same DispatchQueue
    /// with redundant work.
    private var didWarmup = false

    var languageCode: String = "id" {
        didSet {
            let locale = languageCode == "en"
                ? Locale(identifier: "en-US")
                : Locale(identifier: "id-ID")
            speechRecognizer = SFSpeechRecognizer(locale: locale)
        }
    }

    init() {
        // Don't set languageCode here — let the caller configure it.
        // Default to English until told otherwise.
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        // Remove: languageCode = "en"  ← this was triggering didSet redundantly
    }
    
    func warmup() {
        // Idempotent: only the first call kicks off the background
        // MLModel loads. Subsequent calls are no-ops. This makes it
        // safe to call from both `analyze()` (auto-warmup) and any
        // external caller that wants to pre-load on app launch.
        guard !didWarmup else { return }
        didWarmup = true

        // Prime the speech recognizer
        _ = speechRecognizer?.isAvailable
        // Kick off background loads for BOTH language variants so the
        // model is ready by the time the user finishes recording,
        // regardless of which language they pick. Each load is fire-
        // and-forget on a background queue (see
        // `Wav2Vec2AcousticRunner.loadModelAsync`).
        acousticEN.loadModelAsync()
        acousticID.loadModelAsync()
        print("🧠 warmup() dispatched acoustic model loads")
    }
    // MARK: - Live Transcription

    func startLiveTranscription(audioRecorder: AudioRecorder) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized, let self else { return }
            guard let recognizer = self.speechRecognizer, recognizer.isAvailable else { return }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            Task { @MainActor [weak self] in
                self?.setupLiveTask(request: request, audioRecorder: audioRecorder, recognizer: recognizer)
            }
        }
    }

    private func setupLiveTask(
        request: SFSpeechAudioBufferRecognitionRequest,
        audioRecorder: AudioRecorder,
        recognizer: SFSpeechRecognizer
    ) {
        liveRequest = request
        audioRecorder.speechRequest = request
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard error == nil, let result else { return }
            Task { @MainActor [weak self] in
                self?.liveTranscription = result.bestTranscription.formattedString
            }
        }
    }

    func stopLiveTranscription() {
        liveRequest?.endAudio()
        recognitionTask?.cancel()
        liveRequest = nil
        recognitionTask = nil
    }

    // MARK: - Full Analysis

    func analyze(audioData: AudioSampleData) async throws -> AnalysisResult {
        isAnalyzing = true
        progress = 0
        defer { isAnalyzing = false }

        // Auto-warmup: kick off the acoustic model load on the first
        // analysis if no one else called `warmup()` (e.g. on app launch).
        // Subsequent analyze() calls short-circuit thanks to the
        // `didWarmup` guard inside `warmup()`.
        warmup()

        guard let fileURL = audioData.audioFileURL else { throw AnalysisError.noAudioFile }

        let (segments, fullText) = try await transcribe(fileURL: fileURL)
        progress = 0.4

        // ── Pace ──────────────────────────────────────────────────────
        // In analyze(), replace the duration/wpm block:

        // Use actual speech span from segments when available (excludes silence)
        let speechDuration: TimeInterval = {
            guard let first = segments.first, let last = segments.last else {
                return max(audioData.recordingDuration, 1)
            }
            let span = TimeInterval(last.timestamp) + TimeInterval(last.duration)
                - TimeInterval(first.timestamp)
            // If span is implausibly short, fall back to recording duration
            return span > 2.0 ? span : max(audioData.recordingDuration, 1)
        }()

        let wordCount = fullText.split(separator: " ").count
        let duration  = max(speechDuration, 1)
        let wpm       = Double(wordCount) / (duration / 60.0)
        let pace      = paceLabel(for: wpm)

        print("📝 '\(fullText)'")
        print("📝 \(wordCount) words in \(String(format: "%.1f", duration))s (speech span) = \(Int(wpm)) WPM → \(pace)")
        progress = 0.5

        // ── Volume ─────────────────────────────────────────────────────
        let avgDB = audioData.amplitudeSamples.isEmpty ? -60 :
            audioData.amplitudeSamples.reduce(0, +) / Float(audioData.amplitudeSamples.count)
        let vol = volumeLabel(for: avgDB)
        progress = 0.55

        // ── Intonation ─────────────────────────────────────────────────
        let voiced = audioData.pitchSamples.filter { $0 > 0 }
        let pitchMean = voiced.isEmpty ? 0 : voiced.reduce(0, +) / Float(voiced.count)
        let pitchVariance = voiced.isEmpty ? 0 :
            voiced.map { ($0 - pitchMean) * ($0 - pitchMean) }.reduce(0, +) / Float(voiced.count)
        let intonation = pitchVariance < 400 ? "Flat" : "Varied"
        progress = 0.65

        // ── Articulation (dual-path: acoustic Wav2Vec2 + reference) ──
        //
        // Preferred path: run the Wav2Vec2 acoustic model on the
        // 16 kHz resampled audio, align its transcript with the
        // SFSpeechRecognizer reference, and flag words that disagree
        // (highlights mispronounced dictionary words, ignores
        // out-of-vocabulary names/loanwords).
        //
        // Fallback: if the acoustic model isn't loaded (e.g. simulator
        // without the .mlpackage bundled, or loadModelAsync() didn't
        // finish in time), fall back to the legacy Speech-confidence
        // pipeline so the screen always renders something.
        //
        // IMPORTANT for languages where SFSpeech returns confidence=0
        // (notably `id-ID` on iOS 26 simulator where no on-device model
        // is available): the legacy pipeline degrades to "everything is
        // unclear" (score 0). We give the acoustic model a short grace
        // window so a model that finished loading AFTER `analyze()`
        // started (but before this block runs) still gets used.
        let (rawArticulationScore, pronunciationIssues): (Float, [PronunciationIssue]) = await {
            if !acousticRunner.isReady {
                // Short grace window — the MLModel load is async; by the
                // time we reach this line the load may have just finished.
                // Wait up to ~1.5s in 150 ms slices before giving up.
                for _ in 0..<10 where !acousticRunner.isReady {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }
            if acousticRunner.isReady {
                do {
                    let samples = try SpeechAnalyzer.resampleTo16kStatic(fileURL: fileURL)
                    let transcript = acousticRunner.transcribe(samples: samples)
                    let assessments = ArticulationAlignment.run(
                        refSegments: segments,
                        acoustic: transcript,
                        languageCode: languageCode
                    )

                    // ── Reliability check ────────────────────────────
                    // If the acoustic model's output doesn't align well
                    // with the reference (average similarity of scorable
                    // words below threshold), the model is unreliable
                    // for this language/recording. Fall back to legacy.
                    // This commonly triggers for Indonesian Wav2Vec2
                    // which produces high-confidence but inaccurate
                    // character output.
                    let scorable = assessments.filter { $0.decision != .unknownName }
                    let avgSim: Float = scorable.isEmpty ? 0.0 :
                        scorable.map { $0.similarity }.reduce(0, +) / Float(scorable.count)

                    if !assessments.isEmpty && avgSim < 0.40 {
                        print("⚠️ Acoustic model unreliable (avgSim=\(String(format: "%.2f", avgSim)), \(scorable.count) scorable) — falling back to legacy pipeline")
                    } else {
                        return ArticulationPipelineSpeech.runDualPath(
                            segments: segments,
                            assessments: assessments,
                            recordingDuration: duration,
                            languageCode: languageCode
                        )
                    }
                } catch {
                    print("⚠️ Acoustic path failed (\(error)) — falling back to legacy pipeline")
                }
            } else {
                print("⚠️ Acoustic model not ready — falling back to legacy pipeline")
            }
            return ArticulationPipelineSpeech.run(
                segments: segments,
                recordingDuration: duration,
                languageCode: languageCode
            )
        }()
        let articulationScore: Float = (segments.isEmpty && fullText.isEmpty) ? 0.0 : max(rawArticulationScore, 0.0)

        progress = 0.85

        // ── Highlights ─────────────────────────────────────────────────
        let intonationHighlight = bestIntonationSegment(
            pitchSamples: audioData.pitchSamples,
            recordingDuration: duration
        )
        let paceHighlight = bestPaceSegment(
            segments: segments,
            recordingDuration: duration
        )
        progress = 1.0

        return AnalysisResult(
            transcription: fullText,
            duration: duration,
            wordsPerMinute: wpm,
            paceLabel: pace,
            averageAmplitudeDB: avgDB,
            volumeLabel: vol,
            pitchSamples: audioData.pitchSamples,
            pitchVariance: pitchVariance,
            intonationLabel: intonation,
            amplitudeSamples: audioData.amplitudeSamples,
            articulationScore: articulationScore,
            pronunciationIssues: pronunciationIssues,
            audioFileURL: fileURL,
            intonationHighlight: intonationHighlight,
            paceHighlight: paceHighlight
        )
    }
    func reset() {
        progress = 0
        isAnalyzing = false
        liveTranscription = ""
    }

    // MARK: - Transcription

    private func transcribe(fileURL: URL) async throws -> ([SFTranscriptionSegment], String) {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else { throw AnalysisError.notAuthorized }

        // ── Use the configured language, with a fallback ──────────────────
        let primaryLocale = languageCode == "en"
            ? Locale(identifier: "en-US")
            : Locale(identifier: "id-ID")
        let fallbackLocale = languageCode == "en"
            ? Locale(identifier: "en-GB")
            : Locale(identifier: "en-US")   // fallback if id-ID unavailable

        let locales = [primaryLocale, fallbackLocale]

        for locale in locales {
            guard let recognizer = SFSpeechRecognizer(locale: locale),
                  recognizer.isAvailable else {
                print("⚠️ Recognizer unavailable for \(locale.identifier)")
                continue
            }

            for attempt in 1...3 {
                print("🗣️ Attempt \(attempt) with \(locale.identifier)")
                do {
                    let result = try await withCheckedThrowingContinuation {
                        (continuation: CheckedContinuation<([SFTranscriptionSegment], String), Error>) in
                        var resumed = false
                        let request = SFSpeechURLRecognitionRequest(url: fileURL)
                        request.shouldReportPartialResults = false
                        request.addsPunctuation = true
                        if recognizer.supportsOnDeviceRecognition {
                            request.requiresOnDeviceRecognition = true
                        }
                        recognizer.recognitionTask(with: request) { result, error in
                            guard !resumed else { return }
                            if let error {
                                resumed = true
                                continuation.resume(throwing: error)
                                return
                            }
                            guard let result, result.isFinal else { return }
                            resumed = true
                            continuation.resume(returning: (
                                result.bestTranscription.segments,
                                result.bestTranscription.formattedString
                            ))
                        }
                    }
                    print("✅ Transcription (\(locale.identifier)): '\(result.1)'")
                    return result
                } catch {
                    print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < 3 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
                }
            }
        }

        print("⚠️ All transcription attempts failed")
        return ([], "")
    }
    
    // MARK: - Resampling (static so Task.detached can capture it)

    static func resampleTo16kStatic(fileURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: fileURL)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        guard file.length > 0 else { return [] }

        let inputFrameCount = AVAudioFrameCount(file.length)
        guard let inBuf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                           frameCapacity: inputFrameCount) else {
            throw AnalysisError.bufferCreationFailed
        }
        try file.read(into: inBuf)

        let ratio = 16000.0 / file.fileFormat.sampleRate
        let outFrameCount = AVAudioFrameCount(Double(inputFrameCount) * ratio) + 1
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrameCount),
              let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else {
            throw AnalysisError.bufferCreationFailed
        }

        var convErr: NSError?
        var didProvide = false
        converter.convert(to: outBuf, error: &convErr) { _, status in
            if didProvide { status.pointee = .endOfStream; return nil }
            didProvide = true; status.pointee = .haveData; return inBuf
        }
        if let convErr { throw convErr }

        guard let channelData = outBuf.floatChannelData else { return [] }
        let count = min(Int(outBuf.frameLength), 480_000)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }

    // MARK: - Highlight Segments

    private func bestIntonationSegment(pitchSamples: [Float], recordingDuration: TimeInterval) -> AudioHighlightSegment? {
        guard !pitchSamples.isEmpty, recordingDuration > 0 else { return nil }
        let secPerSample = recordingDuration / Double(pitchSamples.count)
        let windowSec = min(15.0, recordingDuration)
        let windowSize = max(1, Int(windowSec / secPerSample))

        if pitchSamples.count <= windowSize {
            return AudioHighlightSegment(startTime: 0, duration: recordingDuration)
        }

        var bestIdx = 0; var bestVar: Float = -1; var i = 0
        while i + windowSize <= pitchSamples.count {
            let w = pitchSamples[i..<(i + windowSize)].filter { $0 > 0 }
            if w.count > 2 {
                let m = w.reduce(0, +) / Float(w.count)
                let v = w.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Float(w.count)
                if v > bestVar { bestVar = v; bestIdx = i }
            }
            i += windowSize / 2
        }
        let startTime = Double(bestIdx) * secPerSample
        _ = Array(pitchSamples[bestIdx..<min(bestIdx + windowSize, pitchSamples.count)])
        return AudioHighlightSegment(startTime: startTime,
                                     duration: min(windowSec, recordingDuration - startTime))
    }

    private func pitchRangeDetail(_ samples: [Float]) -> String {
        let v = samples.filter { $0 > 0 }
        guard !v.isEmpty else { return "No pitch variation detected" }
        let m = v.reduce(0, +) / Float(v.count)
        let variance = v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Float(v.count)
        return String(format: "±%.0f Hz pitch range", sqrt(variance))
    }

    private func bestPaceSegment(segments: [SFTranscriptionSegment], recordingDuration: TimeInterval) -> AudioHighlightSegment? {
        guard !segments.isEmpty, recordingDuration > 0 else { return nil }
        let windowSec = min(15.0, recordingDuration)
        if recordingDuration <= windowSec {
            _ = localWPM(segments: segments, start: 0, duration: recordingDuration)
            return AudioHighlightSegment(startTime: 0, duration: recordingDuration)
        }
        var bestStart = 0.0; var bestDelta = Double.greatestFiniteMagnitude
        var t = 0.0
        while t + windowSec <= recordingDuration {
            let wpm = localWPM(segments: segments, start: t, duration: windowSec)
            let d = abs(wpm - 120)
            if d < bestDelta { bestDelta = d; bestStart = t}
            t += windowSec / 2
        }
        return AudioHighlightSegment(startTime: bestStart, duration: windowSec)
    }

    private func localWPM(segments: [SFTranscriptionSegment], start: TimeInterval, duration: TimeInterval) -> Double {
        let end = start + duration
        let count = segments.filter { TimeInterval($0.timestamp) >= start && TimeInterval($0.timestamp) < end }.count
        return Double(count) / max(duration / 60, 0.001)
    }

    // MARK: - Labels

    private func paceLabel(for wpm: Double) -> String {
        switch wpm {
        case ..<80:    return "Too Slow"
        case 80..<110: return "Slow"
        case 110...130: return "Normal"
        case 130...160: return "Ideal"
        case 160...200: return "Fast"
        default:       return "Too Fast"
        }
    }

    private func volumeLabel(for db: Float) -> String {
        switch db {
        case ..<(-40): return "Too Quiet"
        case (-10)...: return "Too Loud"
        default:       return "Good"
        }
    }
}

// MARK: - Errors

enum AnalysisError: Error, LocalizedError {
    case noAudioFile, notAuthorized, recognizerUnavailable, bufferCreationFailed
    var errorDescription: String? {
        switch self {
        case .noAudioFile:           return "No audio file found."
        case .notAuthorized:         return "Speech recognition not authorized."
        case .recognizerUnavailable: return "Speech recognizer unavailable."
        case .bufferCreationFailed:  return "Failed to process audio."
        }
    }
}



