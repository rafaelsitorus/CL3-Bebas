//
//  HistoryCard.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import SwiftUI

struct HistoryCard: View {
    
    let title: String
    let date: Date
    let duration: TimeInterval
    let issues: [SpeechIssue]
    
    
    private var formattedDate: String {
        date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
        )
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            HStack(alignment: .top) {
                Text(title)
                    .font(Text.CustomHeadline)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formattedDuration)
                    .font(Text.CustomFootnote)
                    .fontWeight(.regular)
            }
            
            Text(formattedDate)
                .font(Text.CustomFootnote)
            
            Divider()
                .frame(height: 0.1)
                .background(Color.black)
                .opacity(0.35)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(issues) { issue in
                        SpeechIssueBadge(issue: issue)
                    }
                }
            }
        }
        .padding(24)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(
            color: .black.opacity(0.1),
            radius: 8,
            y: 4
        )
    }
}

struct SpeechIssueBadge: View {
    let issue: SpeechIssue
    var body: some View {
        Text(issue.title)
            .font(Text.CustomFootnote)
            .foregroundStyle(Color.RedPrimarySC)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.RedSecondarySC)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

enum SpeechIssue: String, CaseIterable, Identifiable {
    case intonation
    case articulation
    case pace
    case volume
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .intonation:
            return "Intonation"
        case .articulation:
            return "Articulation"
        case .pace:
            return "Pace"
        case .volume:
            return "Volume"
        }
    }
}

#Preview {
    HistoryCard(
        title: "Recording_1",
        date: .now,
        duration: 510, // 08:30
        issues: [
            .intonation,
            .articulation,
            .pace,
            .volume
        ]
    )
    .padding()
}
