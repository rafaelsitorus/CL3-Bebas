//
//  AnalysisCategoryCard.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//

import SwiftUI

struct AnalysisCategoryCard: View {

    // MARK: Properties

    let icon: String
    let title: String
    let subtitle: String
    let label: String
    var labelForegroundColor: Color = .primary
    var labelBackgroundColor: Color = Color.primary.opacity(0.05)

    // MARK: Body

    var body: some View {
        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.PrimaryAppColor)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 86, height: 28)
                .foregroundStyle(labelForegroundColor)
                .background(labelBackgroundColor)
                .clipShape(Capsule())

            Image(systemName: AppIcon.chevronRightIcon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .frame(height: 90)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary, lineWidth: 0.3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AnalysisCategoryCard(
            icon: "waveform.path",
            title: "Pace",
            subtitle: "Vocal Tone",
            label: "Expressive"
        )
        
    }
    .padding()
    .background(Color(white: 0.96))
}
