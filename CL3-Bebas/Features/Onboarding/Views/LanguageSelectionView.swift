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
            HStack {
                BackButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Spacer()

            // Globe icon
            AppIconTile(systemName: AppIcon.globe, size: 80, iconSize: 34)
                .padding(.bottom, 24)

            Text("Choose your Language")
                .font(Text.LargeTitle)
                .padding(.bottom, 24)

    

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
            
            Spacer().frame(height: 36)
            
            Text("Select the language you'll use so the system can provide the most precise feedback for your pitch delivery")
                .font(Text.Headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}
