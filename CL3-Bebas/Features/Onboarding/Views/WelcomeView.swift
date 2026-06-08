//
//  WelcomeView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon + name
            VStack(spacing: 14) {
                AppIconTile(systemName: AppIcon.onboardingIcon1, size: 80, iconSize: 36)
                Text("Spitch")
                    .font(.system(size: 28, weight: .bold))
                Text("Time to experience personal analysis pitch")
                    .font(.system(size: 14))
                    .foregroundColor(Color.GreyAccentSC)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 48)

            // Feature list
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    number: 1,
                    icon: AppIcon.micIcon,
                    title: "Record Your Pitch",
                    description: "Practice your pitching by recording\nand reviewing it through our analysis."
                )
                FeatureRow(
                    number: 2,
                    icon: AppIcon.onboardingIcon2,
                    title: "Analyze Your Pitch",
                    description: "See metrics like your intonation,\nvolume, pace, articulation, and filler words."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                PrimaryButton(title: "Continue", action: onContinue)
                    .padding(.horizontal, 24)
                SkipButton(action: onSkip)
            }
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}
