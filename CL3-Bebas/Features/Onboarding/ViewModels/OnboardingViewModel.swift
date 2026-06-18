//
//  OnboardingViewModel.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

import Foundation
import AVFoundation
import Speech
import Combine
import SwiftUI  

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case language
    case quickPitch
    case analysing
    case results
}

enum RecordingState {
    case idle
    case recording
    case playback
    case done
}

enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case indonesian = "Bahasa Indonesia"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .english: return "en-US"
        case .indonesian: return "id-ID"
        }
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Navigation
    @Published var path: NavigationPath = NavigationPath()

    // MARK: - Language
    @Published var selectedLanguage: Language = .english

    // MARK: - Recording
    @Published var recordingState: RecordingState = .idle
    @Published var transcribedText: String = ""
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.05, count: 30)
    @Published var recordingPermissionGranted: Bool = false
    @Published var showPermissionDeniedAlert: Bool = false
    @Published var elapsedSeconds: Int = 0

    // MARK: - Analysis
    @Published var isAnalysing: Bool = false
    @Published var analysisResult: AnalysisResult? = nil

    // MARK: - Private
    private let quickPitchRecorder = AudioRecorder()
    private let analyzer = SpeechAnalyzer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var elapsedTimer: Timer?
    private var recordedSampleData: AudioSampleData?
    private var cancellables = Set<AnyCancellable>()

    init() {
        bindQuickPitchRecorder()
    }

    // MARK: - Navigation Helpers

    func navigate(to step: OnboardingStep) {
        path.append(step)
    }
    
    func goBack() {
        if !path.isEmpty { path.removeLast() }
    }

    func skipOnboarding() {
        // Persist onboarding completion flag
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func requestSpeechPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func handleMicTap() async {
        let micGranted = await requestMicrophonePermission()
        let speechGranted = await requestSpeechPermission()

        guard micGranted && speechGranted else {
            showPermissionDeniedAlert = true
            return
        }
        recordingPermissionGranted = true
        await startRecording()
    }

    // MARK: - Recording

    func startRecording() async {
        guard recordingState == .idle || recordingState == .playback else { return }

        // Also reset transcript + word index when re-recording
        transcribedText = ""
        currentWordIndex = 0
        analysisResult = nil
        recordedSampleData = nil
        quickPitchRecorder.reset()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage.localeIdentifier))
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            showPermissionDeniedAlert = true
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {

                Task { @MainActor in

                    self.transcribedText =
                        result.bestTranscription.formattedString

                    self.updateWordTracking(
                        segments: result.bestTranscription.segments
                    )
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        quickPitchRecorder.speechRequest = recognitionRequest
        quickPitchRecorder.startRecording()

        recordingState = .recording
        elapsedSeconds = 0

        startElapsedTimer()
    }

    func stopRecording() {
        guard recordingState == .recording else { return }

        elapsedTimer?.invalidate()
        audioLevels = Array(repeating: 0.05, count: 30)

        recordedSampleData = quickPitchRecorder.stopRecording()
        stopSpeechRecognition()
        recordingState = .playback
    }

    func submitRecording() {
        if recordingState == .recording {
            stopRecording()
        }
        recordingState = .done
        startAnalysis()
    }

    func resetRecording() {
        // Tear down any live engine/task first
        if recordingState == .recording {
            _ = quickPitchRecorder.stopRecording()
        }
        stopSpeechRecognition()
        elapsedTimer?.invalidate()
        quickPitchRecorder.reset()

        // Reset published state
        recordingState = .idle
        transcribedText = ""
        currentWordIndex = 0
        elapsedSeconds = 0
        audioLevels = Array(repeating: 0.05, count: 30)

        audioPlayer?.stop()
        audioPlayer = nil
        recordedSampleData = nil
        analysisResult = nil
    }

    private var audioPlayer: AVAudioPlayer?

    // Add this method:
    func playback() {
        guard let url = recordedSampleData?.audioFileURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Playback error: \(error)")
        }
    }

    // MARK: - Level Monitoring

    private func bindQuickPitchRecorder() {
        quickPitchRecorder.$currentAmplitude
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rms in
                guard let self, self.recordingState == .recording else { return }
                let newLevel = CGFloat(Self.normalizedLevel(fromRMS: rms))
                self.audioLevels.removeFirst()
                self.audioLevels.append(newLevel)
            }
            .store(in: &cancellables)
    }

    private static func normalizedLevel(fromRMS rms: Float) -> Float {
        guard rms > 0 else { return 0.05 }
        let db = 20 * log10(rms)
        let norm = (db + 55.0) / 55.0
        return max(0.05, min(1.0, norm))
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
            }
        }
    }

    // MARK: - Analysis

    private func startAnalysis() {
        guard let recordedSampleData else { return }
        isAnalysing = true
        path.append(OnboardingStep.analysing)
        Task {
            self.analyzer.languageCode = self.selectedLanguage.analyzerLanguageCode
            let result: AnalysisResult

            do {
                result = try await self.analyzer.analyze(audioData: recordedSampleData)
            } catch {
                result = self.makeFallbackAnalysisResult(from: recordedSampleData)
                print("Quick pitch analysis failed: \(error)")
            }

            self.analysisResult = result
            self.isAnalysing = false
            if !self.path.isEmpty {
                self.path.removeLast()
            }
            self.path.append(OnboardingStep.results)
        }
    }

    private func stopSpeechRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        quickPitchRecorder.speechRequest = nil
    }

    private func makeFallbackAnalysisResult(from audioData: AudioSampleData) -> AnalysisResult {
        let wordCount = transcribedText.split(separator: " ").count
        let duration = max(audioData.recordingDuration, 1)
        let wordsPerMinute = Double(wordCount) / (duration / 60.0)
        let voicedPitchSamples = audioData.pitchSamples.filter { $0 > 0 }
        let meanPitch = voicedPitchSamples.isEmpty ? 0 : voicedPitchSamples.reduce(0, +) / Float(voicedPitchSamples.count)
        let pitchVariance = voicedPitchSamples.isEmpty ? 0 :
            voicedPitchSamples.map { ($0 - meanPitch) * ($0 - meanPitch) }.reduce(0, +) / Float(voicedPitchSamples.count)
        let averageAmplitude = audioData.amplitudeSamples.isEmpty ? -60 :
            audioData.amplitudeSamples.reduce(0, +) / Float(audioData.amplitudeSamples.count)

        return AnalysisResult(
            transcription: transcribedText,
            duration: duration,
            wordsPerMinute: wordsPerMinute,
            paceLabel: paceLabel(for: wordsPerMinute),
            averageAmplitudeDB: averageAmplitude,
            volumeLabel: volumeLabel(for: averageAmplitude),
            pitchSamples: audioData.pitchSamples,
            pitchVariance: pitchVariance,
            intonationLabel: pitchVariance < 400 ? "Flat" : "Varied",
            amplitudeSamples: audioData.amplitudeSamples,
            articulationScore: transcribedText.isEmpty ? 0.4 : 0.7,
            pronunciationIssues: [],
            audioFileURL: audioData.audioFileURL,
            intonationHighlight: AudioHighlightSegment(startTime: 0, duration: min(15, duration)),
            paceHighlight: AudioHighlightSegment(startTime: 0, duration: min(15, duration))
        )
    }

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

    // MARK: - Formatted time

    var elapsedTimeFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: TELEPROMPTER
    @Published var currentWordIndex: Int = 0

    var scriptWords: [String] {
        switch selectedLanguage {
        case .english:
            return """
            Hello I'm practicing my delivery with Spitch to make my next presentation flawless
            """
            .split(separator: " ")
            .map(String.init)

        case .indonesian:
            return """
            Halo saya sedang berlatih penyampaian saya dengan Spitch agar presentasi saya berikutnya berjalan lancar
            """
            .split(separator: " ")
            .map(String.init)
        }
    }

    private func updateWordTracking(
        segments: [SFTranscriptionSegment]
    ) {

        guard let lastSegment = segments.last else {
            currentWordIndex = 0
            return
        }

        let spokenWord = lastSegment.substring
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)

        if let index = scriptWords.firstIndex(where: {
            $0.lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
                == spokenWord
        }) {

            currentWordIndex = index
        }
    }
}

private extension Language {
    var analyzerLanguageCode: String {
        switch self {
        case .english: return "en"
        case .indonesian: return "id"
        }
    }
}
