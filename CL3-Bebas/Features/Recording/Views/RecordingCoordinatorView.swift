//
//  RecordingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

struct RecordPitchCoordinatorView: View {

    // Change signature: onFinished now delivers the captured audio + language
    let onFinished: (AudioSampleData, String) -> Void
    let onLanguageConfirmed: () -> Void
    let onCancelled: () -> Void

    @StateObject private var viewModel: RecordPitchViewModel

    init(
        isPreview: Bool = false,
        onLanguageConfirmed: @escaping () -> Void = {},
        onFinished: @escaping (AudioSampleData, String) -> Void = { _, _ in },
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
                        // Pull the captured audio out of the viewModel
                        // and pass it up with the selected language code
                        if let sample = viewModel.lastSample {
                            let langCode = viewModel.selectedLanguage == .english ? "en" : "id"
                            onFinished(sample, langCode)
                        }
                    },
                    onCancel: { viewModel.goBack() }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: viewModel.currentPage)
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
