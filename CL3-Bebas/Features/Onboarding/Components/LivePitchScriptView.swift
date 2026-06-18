//
//  LivePitchScriptView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 18/06/26.
//

import SwiftUI

struct LivePitchScriptView: View {

    let words: [String]
    let currentIndex: Int

    var body: some View {

        Text(coloredText)
            .font(Text.LargeTitleRegular)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }

    private var coloredText: AttributedString {

        var result = AttributedString()

        for (index, word) in words.enumerated() {

            var part = AttributedString(word + " ")

            if index < currentIndex {
                part.foregroundColor = Color.primary
            } else if index == currentIndex {
                part.foregroundColor = Color.BluePrimaryBC
            } else {
                part.foregroundColor = Color.secondary 
            }

            result += part
        }

        return result
    }
}
