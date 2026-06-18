//
//  PitchResultsView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//


import SwiftUI

struct PitchResultsView: View {
    let result: AnalysisResult
    let onContinue: () -> Void

    private var articulationLabel: String {
        switch result.articulationScore {
        case 0.85...: return "Excellent"
        case 0.70...: return "Good"
        case 0.55...: return "Fair"
        default:      return "Unclear"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack {
                Text("See Your Pitch Analysis and Summarize")
                    .font(Text.CustomLargeTitle)
    
            }
            .padding(.horizontal, 10)
            .multilineTextAlignment(.center)

            Spacer().frame(height: 32)

            // Metric rows
            VStack(spacing: 12) {
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
            .padding(.horizontal, 24)
            .buttonStyle(.plain)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

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
            return (.DarkRed, .TintRed)
        }
    }

    private var articulationColors: (foreground: Color, background: Color) {
        switch result.articulationScore {
        case 0.70...:
            return (.DarkGreen, .TintGreen)
        default:
            return (.DarkRed, .TintRed)
        }
    }
}

