//
//  LanguageSelectionView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//


import SwiftUI

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: Language
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: { dismiss() })

            Spacer()

            // Globe icon
            AppIconTile(systemName: AppIcon.globe, size: 80, iconSize: 36)
                .padding(.bottom, 24)

            Text("Choose your Language")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 12)

            Text("Select the language you'll use so the system\ncan provide the most precise feedback for your\npitch delivery")
                .font(.system(size: 14))
                .foregroundColor(Color.GreyAccentSC)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 36)

            // Language options
            VStack(spacing: 10) {
                ForEach(Language.allCases) { language in
                    LanguageRow(
                        language: language,
                        isSelected: selectedLanguage == language,
                        action: { selectedLanguage = language }
                    )
                }
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
