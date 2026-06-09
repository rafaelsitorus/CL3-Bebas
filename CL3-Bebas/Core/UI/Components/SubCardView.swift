//
//  SubCardView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 05/06/26.
//


import SwiftUI

struct SubCardView: View {
    let title: String
    let description: String
    let icon: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 16) {

            Image(systemName: icon)
                .foregroundColor(accentColor)
                .font(.system(size: 34))

            VStack(alignment: .leading, spacing: 8) {

                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.body)
            }

            Spacer()
        }
        .padding()
        .background(.white)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.MainCard)
                .stroke(
                    Color.gray.opacity(0.4),
                    lineWidth: 0.6
                )
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 8)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: Radius.MainCard)
        )
    }
}

// Cara memakainya begini
#Preview {
    SubCardView(
        title: "How To Improve",
        description: "Add brief pauses between ideas. hbsjhbjhsbhjbsdhbdshj",
        icon: "chart.line.uptrend.xyaxis",
        accentColor: .red
    )
    .padding(.horizontal, 16)
}
