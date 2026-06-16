//
//  ReviewSummaryView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//
//
//  ReviewSummaryView.swift
//  Paralinguistic
//

import SwiftUI


struct ReviewSummaryView: View {

    // MARK: Properties

    let result: AnalysisResult
    var onDismiss: () -> Void = {}

    @StateObject private var player = FullRecordingPlayer()
    @Environment(\.dismiss) private var dismiss

    // MARK: Derived values

    private var scorePercent: Int {
        Int((result.overallScore * 100).rounded())
    }

    private var articulationLabel: String {
        switch result.articulationScore {
        case 0.85...: return "Excellent"
        case 0.70...: return "Good"
        case 0.55...: return "Fair"
        default:      return "Unclear"
        }
    }

    private var recordingDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    navBar
                    sectionLabel("PITCH REVIEW")
                        .padding(.top, 8)
                    titleAndScore
                    playerSection
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    scoreBreakdown
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbarBackground(Color(white: 0.96), for: .navigationBar)
        .tint(.black)
        .onDisappear {
            player.stop()
        }
    }

    // MARK: Sub-views

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.08)))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var titleAndScore: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Title Recording 1")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)

                Text(recordingDateString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(scorePercent)%")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black)

                Text("Score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    private var playerSection: some View {
        FullRecordingPlayerView(player: player, result: result)
            .padding(.horizontal, 20)
            .onAppear {
                if let url = result.audioFileURL {
                    player.load(url: url, duration: result.duration)
                }
            }
    }

    private var scoreBreakdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("SCORE BREAKDOWN")
                .padding(.bottom, 12)

            VStack(spacing: 12) {
                // Pass `result` into each route — this is what was missing
                NavigationLink(value: AppRoute.intonationReview(result)) {
                    AnalysisCategoryCard(
                        icon: "waveform",
                        title: "Intonation",
                        subtitle: "Vocal Tone",
                        label: "Expressive"
                    )
                }

                NavigationLink(value: AppRoute.paceReview(result)) {
                    AnalysisCategoryCard(
                        icon: "timer",
                        title: "Pace",
                        subtitle: "Speaking Speed",
                        label: result.paceLabel
                    )
                }

                NavigationLink(value: AppRoute.articulationReview(result)) {
                    AnalysisCategoryCard(
                        icon: "person.wave.2",
                        title: "Articulation",
                        subtitle: "Clarity of Word",
                        label: articulationLabel
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    

    // MARK: Helpers

    /// Consistent uppercase section-label style used in multiple spots.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReviewSummaryView(
            result: AnalysisResult(
                transcription: "Selamat pagi",
                duration: 20,
                wordsPerMinute: 175,
                paceLabel: "Too Fast",
                averageAmplitudeDB: -22,
                volumeLabel: "Good",
                pitchSamples: [],
                pitchVariance: 600,
                intonationLabel: "Varied",
                amplitudeSamples: [],
                articulationScore: 0.43,
                pronunciationIssues: [],
                audioFileURL: nil,
                intonationHighlight: nil,
                paceHighlight: nil
            )
        )
    }
}
