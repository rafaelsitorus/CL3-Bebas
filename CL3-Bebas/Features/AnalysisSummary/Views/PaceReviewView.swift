//
//  PaceReviewView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 09/06/26.
//

import SwiftUI

struct PaceReviewView: View {
    var body: some View {
        ScrollView {
            VStack (spacing: 30) {
                MainCard()

                SubCardView(
                    title: "How To Improve",
                    description: "Add brief pauses between ideas. hbsjhbjhsbhjbsdhbdshj",
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 18)

                SubCardView(
                    title: "How To Improve",
                    description: "Add brief pauses between ideas. hbsjhbjhsbhjbsdhbdshj",
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 18)

                AudioCard(
                    title: "Listen To An Example",
                    description: "Listen how a good pace can make key points easier to understand.",
                    icon: "headphones",
                    accentColor: .RedPrimarySC
                )
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pace Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PaceReviewView()
    }
}
