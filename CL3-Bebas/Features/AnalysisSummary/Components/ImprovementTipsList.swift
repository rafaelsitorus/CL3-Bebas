//
//  ImprovementTipsList.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import SwiftUI

// MARK: - ImprovementTipsList

struct ImprovementTipsList: View {

    // MARK: Properties

    let tips: [String]

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: AppIcon.bulletPoint)
                        .font(.system(size: 5))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(.top, 9)

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
        "Make sure the beginning and ending sounds of each word can be heard clearly, especially technical terms and key messages.",
        "Open your mouth clearly when speaking to improve word clarity.",
        "Slow down when saying difficult words.",
    ])
    .padding(20)
    .background(Color(white: 0.96))
}
