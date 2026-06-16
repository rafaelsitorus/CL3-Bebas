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

    // Volume bukan metrik utama PitchUp, tidak ditampilkan sebagai badge
    private var displayedIssues: [SpeechIssue] {
        issues.filter { $0 != .volume }
    }

    var body: some View {
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

                // Issue badges
                HStack(spacing: 8) {
                    ForEach(displayedIssues) { issue in
                        SpeechIssueBadge(issue: issue)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        // Tidak ada background/shadow — flat list style
    }
}

// MARK: – Badge (abu-abu, bukan merah)
struct SpeechIssueBadge: View {
    let issue: SpeechIssue

    var body: some View {
        Text(issue.title)
            .font(Text.CustomFootnote)
            .foregroundStyle(Color(.secondaryLabel))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.systemGray4))
            .clipShape(Capsule())
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
        case .intonation:   return "Intonation"
        case .articulation: return "Articulation"
        case .pace:         return "Pace"
        case .volume:       return "Volume"
        }
    }
}

struct HistoryCardLink: View {
    let title: String
    let date: Date
    let duration: TimeInterval
    let issues: [SpeechIssue]
    let onTap: () -> Void

    init(
        title: String,
        date: Date,
        duration: TimeInterval,
        issues: [SpeechIssue],
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.date = date
        self.duration = duration
        self.issues = issues
        self.onTap = onTap
    }

    var body: some View {
        // A plain button (not a NavigationLink) so the parent can
        // decide what to push. This keeps the navigation decisions
        // in the single source of truth (AppRootView).
        Button {
            onTap()
        } label: {
            HistoryCard(
                title: title,
                date: date,
                duration: duration,
                issues: issues
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        VStack(spacing: 0) {
            ForEach(0..<3) { _ in
                HistoryCard(
                    title: "Recording_1",
                    date: .now,
                    duration: 510,
                    issues: [.intonation, .articulation, .pace, .volume]
                )
                Divider().padding(.leading, 20)
            }
        }
        .background(Color(.systemGray6))
    }
}
