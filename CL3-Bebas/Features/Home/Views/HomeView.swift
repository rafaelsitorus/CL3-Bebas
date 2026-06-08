//
//  HomeView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 08/06/26.
//

import SwiftUI

struct HomeView: View {
    private enum Dimension {
        static let width: CGFloat = 360
        static let height: CGFloat = 395
        static let cardStackTopPadding: CGFloat = 56
    }
    
    struct HistoryItem: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let duration: TimeInterval
        let issues: [SpeechIssue]
    }
    
    let cards = (1...6).map { _ in
        CardStackItem(title: "(a)", bodyText: "Listen", image: Image(systemName: "waveform"))
    }
    
    let history: [HistoryItem] = (1...3).map { _ in
        HistoryItem(
            title: "Recording_1",
            date: Date.now,
            duration: 510,
            issues: [
                SpeechIssue.intonation,
                SpeechIssue.articulation,
                SpeechIssue.pace,
                SpeechIssue.volume
            ]
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack {
                    Text("Overall Analysis")
                        .font(Text.TitleHome)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 6)
                    
                    VStack {
                        CardStack(
                            cards: cards,
                            cardWidth: 145,
                            cardHeight: 150
                        )
                        
                        Text("Enhance Your Pitch’s Pace")
                            .offset(y: 54)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .font(Text.CustomHeadline)
                        
                        Text("Pace is the most recurring area for improvement accross your recording. Improving it could strengthen your pitch delivery.")
                            .offset(y: 54)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .font(Text.CustomBody)
                            .padding(.horizontal, 16)
                            .padding(.top, 1)
                    }
                    .padding(.top, Dimension.cardStackTopPadding)
                    .frame(width: Dimension.width, height: Dimension.height, alignment: .top)
                    .background(Color.whiteSC)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 2)
                    
                    HStack {
                        Text("History")
                            .font(Text.TitleHome)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Text("See All >>")
                                .font(Text.CustomBody)
                                .foregroundColor(Color.BluePrimaryBC)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 6)
                    .padding(.top, 12)
                    
                    ForEach(history) { item in
                        HistoryCard(
                            title: item.title,
                            date: item.date,
                            duration: item.duration,
                            issues: item.issues
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 15)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGray6))
            
            CircleIconButton(
                systemName: AppIcon.micIcon,
                shadowColor: Color.black.opacity(0.5),
                shadowRadius: 6,
                shadowX: 0,
                shadowY: 2,
                action: {}
            )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
        }
    }
}

#Preview {
    HomeView()
}
