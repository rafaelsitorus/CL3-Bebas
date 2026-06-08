//
//  AnalyzingView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

//


import SwiftUI

struct AnalyzingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            AppIconTile(systemName: AppIcon.onboardingIcon2, size: 80, iconSize: 36)
                .padding(.bottom, 24)

            Text("Analysing Pitching")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 32)

            ProgressView()
                .scaleEffect(1.4)
                .tint(Color.BluePrimaryBC)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
