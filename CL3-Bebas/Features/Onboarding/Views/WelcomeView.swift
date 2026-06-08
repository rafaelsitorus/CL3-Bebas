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

            VStack() {
                Image(AppImage.logoSpitch)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                Text("Spitch")
                    .font(Text.CustomLargeTitle)
                Text("Time to experience personal analysis pitch")
                    .font(Text.OnboardingCaption)
                    .foregroundColor(Color.GreyAccentSC)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 48)

            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: AppIcon.micIcon,
                    title: "Record Your Pitch",
                    description: "Practice your pitching by recording and reviewing it through our analysis."
                )
                FeatureRow(
                    icon: AppIcon.onboardingIcon2,
                    title: "Analyze Your Pitch",
                    description: "See metrics like your intonation, volume, pace, articulation, and filler words."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

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
