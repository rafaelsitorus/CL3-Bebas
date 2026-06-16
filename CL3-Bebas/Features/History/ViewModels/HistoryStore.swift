//
//  HistoryStore.swift
//  CL3-Bebas
//
//  Shared, lightweight store that keeps the in-memory list of
//  completed recordings. The recording flow appends to this when the
//  user confirms; the History view reads from it.
//
//  Implementation note: this lives in the History view-models folder
//  so the History feature owns the data, but it's exposed as an
//  `ObservableObject` and injected via `.environmentObject(...)` at
//  the app root so any feature can read or write to it.
//

import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {

    @Published private(set) var recordings: [RecordingHistory] = []

    init() {
        // Seed with a few dummy recordings so the History view is not
        // empty on first launch.
        recordings = Self.dummyRecordings
    }

    /// Append a new completed recording. Used by the recording flow
    /// when the user confirms a pitch.
    func append(_ recording: RecordingHistory) {
        recordings.insert(recording, at: 0)
    }

    // MARK: - Dummy seed data

    private static var dummyRecordings: [RecordingHistory] {
        let cal = Calendar.current
        return [
            RecordingHistory(
                title: "Recording 1",
                date: cal.date(from: .init(year: 2026, month: 5, day: 20))!,
                duration: 510,
                issues: [.intonation, .articulation, .pace, .volume]
            ),
            RecordingHistory(
                title: "Recording 2",
                date: cal.date(from: .init(year: 2026, month: 5, day: 19))!,
                duration: 510,
                issues: [.volume]
            ),
            RecordingHistory(
                title: "Recording 3",
                date: cal.date(from: .init(year: 2026, month: 5, day: 18))!,
                duration: 510,
                issues: [.intonation, .volume]
            ),
            RecordingHistory(
                title: "Recording 4",
                date: cal.date(from: .init(year: 2026, month: 5, day: 16))!,
                duration: 510,
                issues: [.intonation, .pace, .volume]
            )
        ]
    }
}
