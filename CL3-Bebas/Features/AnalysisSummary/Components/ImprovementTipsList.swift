//
//  ImprovementTipsList.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import SwiftUI

// MARK: - ImprovementTipsList

/// Renders a white card containing a vertical list of checkmark tips.
/// Used by `ArticulationReviewView`, `IntonationReviewView`, and
/// `PaceReviewView` — replaces the previously duplicated
/// `ForEach + HStack + checkmark.circle` pattern in all three views.
struct ImprovementTipsList: View {

    // MARK: Properties

    let tips: [String]

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(.top, 1)

                    Text(tip)
                        .font(Text.CustomBody)
                        .foregroundStyle(.black.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    ImprovementTipsList(tips: [
        "Emphasize vowel sounds more clearly.",
        "Pronounce each syllable deliberately.",
        "Pay attention to word endings and consonants.",
    ])
    .padding(20)
    .background(Color(white: 0.96))
}
