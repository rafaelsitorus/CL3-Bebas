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
    @State private var recordingTitle: String = "Title Recording 1"
    @State private var isEditingTitle: Bool = false

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

    /// Motivational sentence shown below the player, keyed to the overall score.
    private var scoreFeedback: String {
        switch result.overallScore {
        case 0.85...:
            return "Your pitch scored within the excellent range. Your delivery was clear, engaging, and highly effective."
        case 0.70...:
            return "Your pitch scored within the good range. Your delivery was solid with only minor areas to refine."
        case 0.55...:
            return "Your pitch scored within the fair range. A few adjustments to tone and pace will make a noticeable difference."
        case 0.40...:
            return "Your pitch scored within the developing range. Keep practising — focus on clarity and a steady speaking pace."
        default:
            return "Your pitch is just getting started. Regular practice will help your delivery improve quickly."
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("Pitch Review")
        .tint(.black)
        // Hide the bottom bar (Home / History / Mic) on the review
        // screens so only the native back chevron is available.
        .toolbar(.hidden, for: .bottomBar)
        .onDisappear {
            player.stop()
        }
    }

    private var titleAndScore: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Editable title row
                HStack(spacing: 6) {
                    if isEditingTitle {
                        TextField("Recording title", text: $recordingTitle)
                            .font(Text.TitleRegular)
                            .foregroundStyle(.black)
                            .submitLabel(.done)
                            .onSubmit { isEditingTitle = false }
                    } else {
                        Text(recordingTitle)
                            .font(Text.TitleRegular)
                            .foregroundStyle(.black)
                        
                        Button {
                            isEditingTitle = true
                        } label: {
                            Image(systemName: AppIcon.editPencil)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    
                }

                Text(recordingDateString)
                    .font(Text.CustomFootnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(scorePercent)%")
                    .font(Text.TitleRegular)
                    .foregroundStyle(Color.PrimaryAppColor)

                Text("Score")
                    .font(Text.CustomFootnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FullRecordingPlayerView(player: player, result: result)

            Text(scoreFeedback)
                .font(Text.CustomHeadlineTextRegular)
                .foregroundStyle(Color.TextAppColor)
                .padding(.top, 12)
        }
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
                        label: result.intonationLabel,
                        labelForegroundColor: intonationColors.foreground,
                        labelBackgroundColor: intonationColors.background
                    )
                }

                NavigationLink(value: AppRoute.paceReview(result)) {
                    AnalysisCategoryCard(
                        icon: "timer",
                        title: "Pace",
                        subtitle: "Speaking Speed",
                        label: result.paceLabel,
                        labelForegroundColor: paceColors.foreground,
                        labelBackgroundColor: paceColors.background
                    )
                }

                NavigationLink(value: AppRoute.articulationReview(result)) {
                    AnalysisCategoryCard(
                        icon: "person.wave.2",
                        title: "Articulation",
                        subtitle: "Clarity of Word",
                        label: articulationLabel,
                        labelForegroundColor: articulationColors.foreground,
                        labelBackgroundColor: articulationColors.background
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
    
    // MARK: Color Tokens
    private var intonationColors: (foreground: Color, background: Color) {
        if result.intonationLabel.localizedCaseInsensitiveContains("flat") {
            return (.DarkRed, .TintRed)
        } else {
            return (.DarkGreen, .TintGreen)
        }
    }

    private var paceColors: (foreground: Color, background: Color) {
        if result.paceLabel.localizedCaseInsensitiveContains("ideal") ||
           result.paceLabel.localizedCaseInsensitiveContains("normal") {
            return (.DarkGreen, .TintGreen)
        } else {
            return (.DarkRed, .TintRed) // "Too Fast" or "Too Slow"
        }
    }

    private var articulationColors: (foreground: Color, background: Color) {
        switch result.articulationScore {
        case 0.70...:
            return (.DarkGreen, .TintGreen) // "Excellent" or "Good"
        default:
            return (.DarkRed, .TintRed)     // "Fair" or "Unclear"
        }
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
