//
//  HomeView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 08/06/26.
//

import SwiftUI

struct ArticleView: View {
    let imageName: String
    let title: String
    let status: String
    let description: String

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ARTICLE")
                        .font(Text.CustomExpandedSH)
                        .padding(.top)
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom)

                    Text(title)
                        .font(Text.CustomCondensedSH)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    Text(status)
                        .font(Text.TitleRegular)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    Divider()
                        .frame(height: 1)
                        .background(Color.gray.opacity(0.35))
                        .padding(.horizontal)
                        .padding(.top, 12)

                    Text(description)
                        .font(Text.CustomBody)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                        .padding(.top)
                }
            }
        }
        // The native navigation title + back chevron come from the
        // enclosing NavigationStack. We expose the article headline
        // as the large title so it reads naturally when pushed from
        // HomeView.
        .navigationTitle(status)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ArticleView(
            imageName: "GreyImg",
            title: "PITCHING TIPS",
            status: "How To Control Your Speaking Pace Under Pressure",
            description:
    """
Speaking under pressure often causes people to speed up without realizing it. When this happens, listeners may struggle to follow your message, and important points can lose their impact.

One effective way to manage your pace is to use intentional pauses. Brief pauses between ideas give you time to think while allowing listeners to absorb what you have said. Focusing on key messages rather than rushing through every sentence can also help maintain a steady rhythm.

Before an important presentation, practice speaking slightly slower than feels natural. During the presentation, take a breath before introducing a new idea and pause after delivering an important point. These small adjustments can make your speech sound more confident, clear, and engaging, even in high-pressure situations.
"""
        )
    }
}
