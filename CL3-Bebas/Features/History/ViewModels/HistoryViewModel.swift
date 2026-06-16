//
//  HistoryViewModel.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import Foundation
import Observation

struct RecordingHistory: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let duration: TimeInterval
    let issues: [SpeechIssue]
}

@Observable
final class HistoryViewModel {

    var recordings: [RecordingHistory] = []

    init() {
        loadDummyData()
    }

    private func loadDummyData() {
        let calendar = Calendar.current

        recordings = [
            RecordingHistory(
                title: "Recording_1",
                date: calendar.date(from: .init(year: 2026, month: 5, day: 20))!,
                duration: 510,
                issues: [
                    .intonation,
                    .articulation,
                    .pace,
                    .volume
                ]
            ),

            RecordingHistory(
                title: "Recording_2",
                date: calendar.date(from: .init(year: 2026, month: 5, day: 19))!,
                duration: 510,
                issues: [
                    .volume
                ]
            ),

            RecordingHistory(
                title: "Recording_3",
                date: calendar.date(from: .init(year: 2026, month: 5, day: 18))!,
                duration: 510,
                issues: [
                    .intonation,
                    .volume
                ]
            ),

            RecordingHistory(
                title: "Recording_4",
                date: calendar.date(from: .init(year: 2026, month: 5, day: 16))!,
                duration: 510,
                issues: [
                    .intonation,
                    .pace,
                    .volume
                ]
            )
        ]
    }
}
