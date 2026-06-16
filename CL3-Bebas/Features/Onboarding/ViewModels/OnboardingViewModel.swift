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

struct PitchAnalysisResult: Hashable {
    var pace: PaceRating
    var articulation: ArticulationRating
    var intonation: IntonationRating

    enum PaceRating: String, Hashable { case tooFast = "Too Fast", good = "Good", tooSlow = "Too Slow" }
    enum ArticulationRating: String, Hashable { case unclear = "Unclear", clear = "Clear", veryClear = "Very Clear" }
    enum IntonationRating: String, Hashable { case expressive = "Expressive", flat = "Flat", varied = "Varied" }
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
    @Published var analysisResult: PitchAnalysisResult? = nil

    // MARK: - Private
    private var audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var levelTimer: Timer?
    private var elapsedTimer: Timer?
    private var recordedFileURL: URL?

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

    /// Call this when the user taps the mic button for the first time.
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
        guard recordingState == .idle else { return }

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage.localeIdentifier))

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recordingState = .recording
        elapsedSeconds = 0

        startLevelMonitoring()
        startElapsedTimer()
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        levelTimer?.invalidate()
        elapsedTimer?.invalidate()
        audioLevels = Array(repeating: 0.05, count: 30)

        recordingState = .playback
    }

    func submitRecording() {
        stopRecording()
        recordingState = .done
        startAnalysis()
    }

    // MARK: - Level Monitoring

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let newLevel = CGFloat.random(in: 0.05...1.0)
                self.audioLevels.removeFirst()
                self.audioLevels.append(newLevel)
            }
        }
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
        path.append(OnboardingStep.analysing)
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                self.analysisResult = PitchAnalysisResult(
                    pace: .tooFast,
                    articulation: .unclear,
                    intonation: .expressive
                )
                // Replace analysing with results
                self.path.removeLast()
                self.path.append(OnboardingStep.results)
            }
        }
    }

    // MARK: - Formatted time

    var elapsedTimeFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
