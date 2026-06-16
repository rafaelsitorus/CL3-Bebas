//
//  RecordingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

struct RecordPitchCoordinatorView: View {

    // Change signature: onFinished now delivers the analysis result
    let onFinished: (AnalysisResult) -> Void
    let onLanguageConfirmed: () -> Void
    let onCancelled: () -> Void

    @StateObject private var viewModel: RecordPitchViewModel
    @State private var analyzer = SpeechAnalyzer()
    @State private var analysisError: String?

    init(
        isPreview: Bool = false,
        onLanguageConfirmed: @escaping () -> Void = {},
        onFinished: @escaping (AnalysisResult) -> Void = { _ in },
        onCancelled: @escaping () -> Void = {}
    ) {
        self.onLanguageConfirmed = onLanguageConfirmed
        self.onFinished = onFinished
        self.onCancelled = onCancelled
        _viewModel = StateObject(wrappedValue: RecordPitchViewModel(isPreview: isPreview))
    }

    var body: some View {
        ZStack {
            switch viewModel.currentPage {
            case .languageSelection:
                RecordingLanguageSelectionView(
                    viewModel: viewModel,
                    onConfirm: { onLanguageConfirmed() },
                    onCancel: { onCancelled() }
                )
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))

            case .recording:
                RecordingView(
                    viewModel: viewModel,
                    onConfirm: {
                        // Move to analyzing page — analysis starts in .onAppear
                        viewModel.currentPage = .analyzing
                    },
                    onCancel: { viewModel.goBack() }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))

            case .analyzing:
                AnalyzingRecordingView()
                    .transition(.opacity)
                    .onAppear { startAnalysis() }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: viewModel.currentPage)
        .alert("Analysis Failed", isPresented: .init(
            get: { analysisError != nil },
            set: { if !$0 { analysisError = nil } }
        )) {
            Button("Retry") { startAnalysis() }
            Button("Cancel", role: .cancel) { onCancelled() }
        } message: {
            Text(analysisError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Analysis

    private func startAnalysis() {
        guard let sample = viewModel.lastSample else { return }
        let langCode = viewModel.selectedLanguage == .english ? "en" : "id"
        analyzer.languageCode = langCode

        Task {
            do {
                let result = try await analyzer.analyze(audioData: sample)
                onFinished(result)
            } catch {
                analysisError = error.localizedDescription
            }
        }
    }
}

// MARK: - Previews
#Preview("Language Selection page") {
    RecordPitchCoordinatorView(isPreview: true)
}

#Preview("Recording page") {
    let vm = RecordPitchViewModel(isPreview: true)
    vm.currentPage  = .recording
    vm.isRecording  = true
    vm.waveformBars = (0..<60).map { i in
        let t = Float(i) / 60
        return max(0.12, abs(sin(t * .pi * 6)) * 0.88 + Float.random(in: -0.08...0.08))
    }
    return RecordingView(viewModel: vm)
}
