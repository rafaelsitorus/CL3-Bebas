//
//  RecordingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

struct RecordPitchCoordinatorView: View {

    /// Fired when the user has finished their pitch and confirmed
    /// the recording (e.g. taps the checkmark on the recording page).
    let onFinished: () -> Void

    /// Fired when the user confirms a language and moves from the
    /// language-selection page into the recording page.
    let onLanguageConfirmed: () -> Void

    /// Fired when the user explicitly cancels / dismisses the
    /// recording flow before finishing.
    let onCancelled: () -> Void

    @StateObject private var viewModel: RecordPitchViewModel

    init(
        isPreview: Bool = false,
        onLanguageConfirmed: @escaping () -> Void = {},
        onFinished: @escaping () -> Void = {},
        onCancelled: @escaping () -> Void = {}
    ) {
        self.onLanguageConfirmed = onLanguageConfirmed
        self.onFinished = onFinished
        self.onCancelled = onCancelled

        _viewModel = StateObject(
            wrappedValue: RecordPitchViewModel(
                isPreview: isPreview
            )
        )
    }

    var body: some View {
        ZStack {
            switch viewModel.currentPage {

            case .languageSelection:
                RecordingLanguageSelectionView(
                    viewModel: viewModel,
                    onConfirm: {
                        // Notify the host that the user has moved past
                        // language selection. After this point the
                        // coordinator must behave as a one-time form.
                        onLanguageConfirmed()
                    },
                    onCancel: {
                        onCancelled()
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    )
                )

            case .recording:
                RecordingView(
                    viewModel: viewModel,
                    onConfirm: onFinished,
                    // Once the user is on the recording page, the
                    // "checklist" / back button must NOT let them
                    // return to a previous recording — it should
                    // dismiss the cover instead.
                    onCancel: onCancelled
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    )
                )
            }
        }
        .animation(
            .easeInOut(duration: 0.28),
            value: viewModel.currentPage
        )
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
