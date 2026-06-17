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
        // The coordinator owns its own NavigationStack so the inner
        // views can declare navigation titles. The single toolbar
        // block below renders EXACTLY ONE back button and EXACTLY
        // ONE confirm button, no matter which inner page is
        // currently active. (Previously each inner view declared
        // its own toolbar and a ZStack mounted both, which produced
        // duplicate buttons.)
        NavigationStack {
            ZStack {
                RecordingLanguageSelectionView(
                    viewModel: viewModel,
                    onConfirm: { onLanguageConfirmed() },
                    onCancel: { onCancelled() }
                )
                .opacity(viewModel.currentPage == .languageSelection ? 1 : 0)
                .allowsHitTesting(viewModel.currentPage == .languageSelection)

                RecordingView(
                    viewModel: viewModel,
                    onConfirm: {
                        // We do not block on the captured audio here —
                        // the host just needs the language code to
                        // build a dummy result while the real
                        // analyzer is being wired up.
                        let langCode = viewModel.selectedLanguage == .english ? "en" : "id"
                        if let sample = viewModel.lastSample {
                            onFinished(sample, langCode)
                        } else {
                            // lastSample may be nil if the user
                            // tapped confirm before the recorder
                            // produced any samples. Pass an empty
                            // sample — the host can still build a
                            // dummy result.
                            onFinished(
                                AudioSampleData(
                                    recordingDuration: TimeInterval(viewModel.elapsedSeconds)
                                ),
                                langCode
                            )
                        }
                    },
                    onCancel: { viewModel.goBack() }
                )
                .opacity(viewModel.currentPage == .recording ? 1 : 0)
                .allowsHitTesting(viewModel.currentPage == .recording)
            }
            // A short, snappy transition between pages.
            .animation(.easeOut(duration: 0.18), value: viewModel.currentPage)
        }
        // The coordinator is the single owner of the toolbar. We
        // expose:
        //   - a top-leading back / cancel button (always)
        //   - a top-trailing check button ONLY on the language
        //     selection page (the user needs it to advance to the
        //     recording page). On the recording page we omit it
        //     because the page already has its own on-screen finish
        //     button (the red `square.fill` stop button in the
        //     RecordingControlBar).
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onCancelled()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
            }
            if viewModel.currentPage == .languageSelection {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.confirmLanguageSelection()
                        onLanguageConfirmed()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Continue")
                }
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
    return NavigationStack {
        RecordingView(viewModel: vm)
    }
}
