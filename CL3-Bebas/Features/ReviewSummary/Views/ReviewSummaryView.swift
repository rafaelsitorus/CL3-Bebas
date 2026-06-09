//
//  ReviewSummaryView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

import SwiftUI

struct ReviewSummaryView: View {

    // MARK: - Dependencies

    @StateObject private var viewModel: ReviewSummaryViewModel
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    let onPaceTap: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(
        result: PitchAnalysisResult,
        onContinue: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        onPaceTap: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ReviewSummaryViewModel(result: result))
        self.onContinue = onContinue
        self.onBack = onBack
        self.onPaceTap = onPaceTap
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                RecordingHeaderCard(
                    title: "Title Recording 1",
                    duration: "Duration",
                    date: "Date",
                    audioLevels: viewModel.sampleLevels,
                    isPlaying: viewModel.isPlaying,
                    onPlayTap: viewModel.togglePlayback
                )

                MetricCard(
                    icon: AppIcon.intonation,
                    title: "Intonation",
                    subtitle: "Vocal Tone",
                    accentColor: viewModel.result.intonation.labelColor,
                    labelText: viewModel.result.intonation.rawValue,
                    labelColor: viewModel.result.intonation.labelColor,
                    progress: viewModel.intonationProgress,
                    onTap: {
                        
                    }
                )

                MetricCard(
                    icon: AppIcon.pace,
                    title: "Pace",
                    subtitle: "Speaking Speed",
                    accentColor: viewModel.result.pace.labelColor,
                    labelText: viewModel.result.pace.rawValue,
                    labelColor: viewModel.result.pace.labelColor,
                    progress: viewModel.paceProgress,
                    onTap: {
                        onPaceTap()
                    }
                )

                MetricCard(
                    icon: AppIcon.articulation,
                    title: "Articulation",
                    subtitle: "Clarity of Word",
                    accentColor: viewModel.result.articulation.labelColor,
                    labelText: viewModel.result.articulation.rawValue,
                    labelColor: viewModel.result.articulation.labelColor,
                    progress: viewModel.articulationProgress,
                    onTap: {}
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Pitch Review")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func handleBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReviewSummaryView(
            result: PitchAnalysisResult(
                pace: .tooFast,
                articulation: .unclear,
                intonation: .expressive
            ),
            onContinue: {
            },
            onPaceTap: {}
        )
    }
}
