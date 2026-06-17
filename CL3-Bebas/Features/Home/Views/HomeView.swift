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
    let cardSpacing: CGFloat = 4

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

                    PartitionedProgressBar(value: 53)

                    Spacer()

                    Text("Your pitching performance demonstrates a highly commendable upward.")
                        .font(Text.CustomBody)
                        .padding(.leading)
                        .padding(.bottom, 32)

                    // Only the overall cards carousel is center-aligned
                    // — the rest of the page keeps its original left
                    // alignment.
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
                        .contentMargins(.horizontal, (geo.size.width - cardWidth) / 2, for: .scrollContent)
                    }
                        .frame(height: 200)

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
    }
}

struct PartitionedProgressBar: View {
    var value: Double
    var total: Double = 100
    
    // Label untuk masing-masing partisi
    let labels = ["Weak", "Developing", "Strong", "Excellent"]
    
    var body: some View {
        HStack(spacing: 3) { // Jarak antar partisi
            ForEach(0..<4, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    // Bagian Bar (Batang Progress)
                    GeometryReader { geo in
                        let segmentValue = total / 4.0
                        let segmentStart = Double(index) * segmentValue
                        
                        let fillRatio = max(0, min(1, (value - segmentStart) / segmentValue))
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.gray.opacity(0.3))
                            
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.primary)
                                .frame(width: geo.size.width * CGFloat(fillRatio))
                        }
                    }
                    .frame(height: 8)
                    
                    // Bagian Label Teks
                    Text(labels[index])
                        .font(.caption)
                        .foregroundColor(.primary)
                        // MODIFIKASI DI SINI: Jika index ke-3 (Excellent), rata kanan. Selain itu rata kiri.
                        .frame(maxWidth: .infinity, alignment: (index == 2 || index == 3) ? .trailing : .leading)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
}
