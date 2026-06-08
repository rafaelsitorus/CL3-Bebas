//
//  LabelBadge.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 09/06/26.
//

import SwiftUI

struct LabelBadge: View {
    let text: String
    let textColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(textColor)
            .frame(width: 86, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
    }
}
