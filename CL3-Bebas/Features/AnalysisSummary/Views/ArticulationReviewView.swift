//
//  ArticulationReviewView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 09/06/26.
//

import SwiftUI

struct ArticulationReviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                MainCard()

                SubCardView(
                    title: "How To Improve",
                    description: "Speak slowly and exaggerate the movements of your mouth. Practice tongue twisters regularly to train clear pronunciation.",
                    icon: "mouth",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 18)

                SubCardView(
                    title: "Common Pitfalls",
                    description: "Mumbling, dropping word endings, and speaking too quickly all hurt articulation. Pause between phrases to reset.",
                    icon: "exclamationmark.bubble",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 18)

                AudioCard(
                    title: "Listen To An Example",
                    description: "Hear how crisp articulation can make every word easier to follow.",
                    icon: "headphones",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Articulation Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ArticulationReviewView()
    }
}
