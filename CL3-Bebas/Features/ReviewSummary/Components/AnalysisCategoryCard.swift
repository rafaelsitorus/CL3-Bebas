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

    // MARK: Body

    var body: some View {
        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 86, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 18)
        .frame(height: 90)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 0.3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
