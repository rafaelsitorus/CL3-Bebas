//
//  HomeView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 08/06/26.
//

import SwiftUI

struct HomeView: View {
    @State private var scrollPosition: Int? = 0

    let cardWidth: CGFloat = 320
    let cardSpacing: CGFloat = 2

    /// Triggered when the user taps an article card.
    /// Connected natively by the root NavigationStack.
    let onArticleTap: (Article) -> Void

    init(onArticleTap: @escaping (Article) -> Void = { _ in }) {
        self.onArticleTap = onArticleTap
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OVERALL ANALYSIS")
                        .font(Text.CustomExpandedSH)
                        .padding(.top)
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text("53").customExpandedBT(size: 90)
                            .padding(.leading)

                        VStack {
                            Text("%")
                                .customExpandedBT(size: 25)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Progressing")
                                .font(Text.CustomExpandedT2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    ProgressView(value: 53, total: 100)
                        .progressViewStyle(.linear)
                        .tint(.primary)
                        .background(Color.gray.opacity(0.2))
                        .scaleEffect(x: 1, y: 2.5, anchor: .center)
                        .frame(height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.ProgressBar))
                        .padding(.horizontal)

                    Spacer()

                    Text("Your pitching performance demonstrates a highly commendable upward.")
                        .font(Text.CustomBody)
                        .padding(.leading)
                        .padding(.bottom, 32)

                    GeometryReader { geo in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: cardSpacing) {
                                ForEach(0..<3, id: \.self) { index in
                                    OverallCard(
                                        title: "Pace",
                                        status: "Too Fast",
                                        description: "You're speaking too quickly. Focus on pausing between sentences and key ideas to improve clarity.",
                                        iconName: AppIcon.paceGauge
                                    )
                                    .frame(width: cardWidth)
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollClipDisabled()
                        .scrollPosition(id: $scrollPosition)
                        .contentMargins(.horizontal, 2, for: .scrollContent)
                    }
                        .frame(height: 220)

                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == (scrollPosition ?? 0)
                                        ? Color.primary
                                        : Color.gray.opacity(0.35)
                                )
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: scrollPosition)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                    Divider()
                        .frame(height: 1)
                        .background(Color.gray.opacity(0.35))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Text("ARTICLE")
                        .font(Text.CustomExpandedSH)
                        .padding(.top)
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Tapping the article card pushes ArticleView natively
                    // onto the main NavigationStack via the callback
                    // supplied by AppRootView.
                    Button {
                        onArticleTap(Article.pitchingTips)
                    } label: {
                        ArticleCard(
                            imageName: "GreyImg",
                            title: "PITCHING TIPS",
                            status: "How To Control Your Speaking Pace Under Pressure"
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.lightGrayBC)
    }
}

#Preview {
    HomeView()
}
