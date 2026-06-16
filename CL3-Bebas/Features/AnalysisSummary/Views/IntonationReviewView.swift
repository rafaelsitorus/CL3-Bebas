//
//  IntonationReviewView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 09/06/26.
//

import SwiftUI

struct IntonationReviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                MainCard()

                SubCardView(
                    title: "How To Improve",
                    description: "Vary your pitch across sentences — raise it for questions, lower it for statements, and emphasize key words to add meaning.",
                    icon: "waveform.path.ecg",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 18)

                SubCardView(
                    title: "Avoid Monotony",
                    description: "A flat tone can make even great content sound dull. Highlight contrasts to keep the listener engaged.",
                    icon: "chart.bar",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 18)

                AudioCard(
                    title: "Listen To An Example",
                    description: "Hear how expressive intonation transforms a sentence from flat to engaging.",
                    icon: "headphones",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Intonation Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        IntonationReviewView()
    }
}
