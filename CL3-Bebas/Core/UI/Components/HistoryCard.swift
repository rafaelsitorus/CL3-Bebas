//
//  HistoryCard.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import SwiftUI

// MARK: - Label descriptor

/// A small value type describing one coloured badge on a History card.
/// Each badge shows "Category: Value" (e.g. "Intonation: Expressive")
/// with foreground/background colours that match the ReviewSummary
/// colour scheme.
struct HistoryLabelInfo: Identifiable {
    let id = UUID()
    let text: String               // e.g. "Intonation: Varied"
    let foregroundColor: Color
    let backgroundColor: Color
}

// MARK: - HistoryCard

struct HistoryCard: View {

    let title: String
    let date: Date
    let duration: TimeInterval
    let scorePercent: Int
    let labels: [HistoryLabelInfo]

    // "20 May 2026"
    private var formattedDate: String {
        date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
        )
    }

    // "08:30"
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(title)
                        .font(Text.CustomHeadline)
                        .foregroundStyle(.primary)

                    // "20 May 2026  |  08:30"
                    HStack(spacing: 6) {
                        Text(formattedDate)
                        Text("|")
                        Text(formattedDuration)
                    }
                    .font(Text.CustomFootnote)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Score percentage & Chevron
                HStack(spacing: 12) {
                    Text("\(scorePercent)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            // Coloured label badges (placed in the outer VStack so it spans the entire card width)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(labels) { label in
                        Text(label.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(label.foregroundColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(label.backgroundColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: – SpeechIssue (unchanged)

enum SpeechIssue: String, CaseIterable, Identifiable {
    case intonation
    case articulation
    case pace
    case volume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intonation:   return "Intonation"
        case .articulation: return "Articulation"
        case .pace:         return "Pace"
        case .volume:       return "Volume"
        }
    }
}

// MARK: – HistoryCardLink

struct HistoryCardLink: View {
    let title: String
    let date: Date
    let duration: TimeInterval
    let scorePercent: Int
    let labels: [HistoryLabelInfo]
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HistoryCard(
                title: title,
                date: date,
                duration: duration,
                scorePercent: scorePercent,
                labels: labels
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layout helpers (removed unused FlowLayout)

// MARK: - Preview

#Preview {
    NavigationStack {
        VStack(spacing: 0) {
            ForEach(0..<3) { _ in
                HistoryCard(
                    title: "Recording_1",
                    date: .now,
                    duration: 510,
                    scorePercent: 70,
                    labels: [
                        HistoryLabelInfo(text: "Intonation: Expressive", foregroundColor: .DarkGreen, backgroundColor: .TintGreen),
                        HistoryLabelInfo(text: "Articulation: Unclear", foregroundColor: .DarkRed, backgroundColor: .TintRed),
                        HistoryLabelInfo(text: "Pace: Normal", foregroundColor: .DarkGreen, backgroundColor: .TintGreen),
                    ]
                )
                Divider().padding(.leading, 20)
            }
        }
        .background(Color.lightGrayBC)
    }
}
