//
//  AnalyzingRecordingView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 17/06/26.
//

import SwiftUI

// MARK: - Analyzing Recording View
/// Full-screen loading view shown inside the recording flow
/// while the speech analysis model processes the audio.
struct AnalyzingRecordingView: View {

    // Pulsing animation state
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon tile
            AppIconTile(
                systemName: AppIcon.onboardingIcon2,
                size: 80,
                iconSize: 36
            )
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .padding(.bottom, 28)

            // Title
            Text("Analysing Your Pitch")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)

            // Subtitle
            Text("Please wait while we process\nyour recording…")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)

            // Spinner
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(Color.BluePrimaryBC)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isPulsing = true }
    }
}

// MARK: - Preview
#Preview("Analyzing") {
    NavigationStack {
        AnalyzingRecordingView()
    }
}
