//
//  PitchResultsView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//


import SwiftUI

struct PitchResultsView: View {
    let result: PitchAnalysisResult
    let onContinue: () -> Void

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
                MetricRow(
                    icon: AppIcon.pace,
                    iconColor: Color.RedPrimarySC,
                    label: "Pace",
                    value: result.pace.rawValue
                )
                MetricRow(
                    icon: AppIcon.articulation,
                    iconColor: Color.RedPrimarySC,
                    label: "Articulation",
                    value: result.articulation.rawValue
                )
                MetricRow(
                    icon: AppIcon.intonation,
                    iconColor: Color.BluePrimaryBC,
                    label: "Intonation",
                    value: result.intonation.rawValue
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}


