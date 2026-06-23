//
//  RecordingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

/// Each route in the recording coordinator's internal NavigationStack.
enum RecordPitchStep: Hashable {
    case recording
}

struct RecordPitchCoordinatorView: View {

    // Change signature: onFinished now delivers the captured audio + language + title
    let onFinished: (AudioSampleData, String, String) -> Void
    let onLanguageConfirmed: () -> Void
    let onCancelled: () -> Void

    @StateObject private var viewModel: RecordPitchViewModel

    /// Native navigation path. Empty = language-selection root
    /// showing; `.recording` pushed on top when the user advances.
    /// Using a `NavigationStack(path:)` here (instead of swapping
    /// via `ZStack` + opacity) is what gives the system back
    /// gesture — slide right from the left edge pops the
    /// recording page and returns to language selection, exactly
    /// like a normal SwiftUI push.
    @State private var path: [RecordPitchStep] = []

    init(
        isPreview: Bool = false,
        onLanguageConfirmed: @escaping () -> Void = {},
        onFinished: @escaping (AudioSampleData, String, String) -> Void = { _, _, _ in },
        onCancelled: @escaping () -> Void = {}
    ) {
        self.onLanguageConfirmed = onLanguageConfirmed
        self.onFinished = onFinished
        self.onCancelled = onCancelled
        _viewModel = StateObject(wrappedValue: RecordPitchViewModel(isPreview: isPreview))
    }

    var body: some View {
        // Single `NavigationStack` whose root is the language
        // selection page and whose pushed destination is the
        // recording page. The back chevron and the iOS edge
        // gesture pop the recording destination back to language
        // selection — no `ZStack`-swap trick.
        NavigationStack(path: $path) {
            RecordingLanguageSelectionView(
                viewModel: viewModel,
                onConfirm: {
                    // User tapped the checkmark in
                    // language-selection. Advance to the recording
                    // page by pushing onto the stack — this is the
                    // only path mutation we make here, so the back
                    // gesture works natively.
                    path.append(.recording)
                    onLanguageConfirmed()
                },
                onCancel: { onCancelled() }
            )
            .navigationDestination(for: RecordPitchStep.self) { step in
                switch step {
                case .recording:
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
                        // "Back" from the recording page returns to
                        // language selection by popping the stack
                        // (instead of dismissing the whole cover).
                        // We also clear the recording state so a
                        // re-entry starts from scratch.
                        onCancel: {
                            viewModel.goBack()
                            if !path.isEmpty { path.removeLast() }
                        }
                    )
                }
            }
        }
        // The toolbar lives on each child view — see
        // `RecordingLanguageSelectionView` for the Continue
        // checkmark + cancel chevron on the root, and the
        // system back chevron on the pushed `RecordingView`
        // destination. We intentionally do NOT attach a
        // `.toolbar` here at the coordinator level because
        // toolbar items declared on a NavigationStack's
        // outer container apply to the root only — putting
        // them on the children keeps each view self-contained
        // and gives us a native back button on the recording
        // destination that the system gesture can pop.
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
