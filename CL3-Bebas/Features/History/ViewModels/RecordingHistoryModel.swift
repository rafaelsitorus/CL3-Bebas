//
//  RecordingHistoryModel.swift
//  CL3-Bebas
//
//  SwiftData `@Model` for a completed recording.
//
//  Replaces the old in-memory `RecordingHistory` struct + `HistoryStore`
//  dummy seed with a real, persistent SwiftData entity. Every time the
//  user finishes recording and analysis completes, the app inserts a
//  new `RecordingHistoryModel` into the shared `ModelContainer` — that
//  row is what powers the History list and the per-row tap (which
//  rebuilds an `AnalysisResult` from the stored metrics and pushes
//  `ReviewSummary` onto the main NavigationStack).
//
//  IMPORTANT — we persist *every* field that the downstream review
//  screens (Pace, Articulation, Intonation, Unclear Words) read from
//  `AnalysisResult`. If a field is missing here, the corresponding
//  detail screen will render an empty / "no data" state when the
//  user re-opens a recording from History. See `toAnalysisResult()`
//  for the rebuild path.
//

import Foundation
import SwiftData

/// Persisted record of a single completed pitch. One row per recording.
///
/// `issueRawValues` stores the `SpeechIssue` raw strings (e.g. "intonation",
/// "pace"). SwiftData can store `[String]` directly, and we decode back to
/// `[SpeechIssue]` in the computed `issues` property so the existing
/// `HistoryCard` / filter / sort code keeps working unchanged.
@Model
final class RecordingHistoryModel {

    /// Stable identifier. We also use the SwiftData `PersistentIdentifier`
    /// for uniqueness, but a UUID gives us a stable id that survives
    /// in-memory `RecordingHistory` snapshots (used in `ForEach`).
    @Attribute(.unique) var id: UUID

    /// Display title (e.g. "Recording 1"). The user can edit this on
    /// `ReviewSummaryView`; edits are written back to SwiftData via
    /// the `\.modelContext` so the new title shows up in the History
    /// list as soon as the user navigates back.
    var title: String

    /// Wall-clock time the recording finished.
    var date: Date

    /// Recording duration in seconds (excludes paused time, matches the
    /// value `AudioRecorder.stopRecording()` returns).
    var duration: TimeInterval

    /// Raw `SpeechIssue` strings — `intonation` / `articulation` /
    /// `pace` / `volume`. Stored as strings so the schema is stable
    /// even if we add/remove cases later (we just filter unknown
    /// values on read).
    var issueRawValues: [String]

    /// Language used for the recording: "en" or "id". Stored so the
    /// History detail can re-run transcription with the same locale if
    /// we ever need to.
    var languageCode: String

    // MARK: - Persisted analysis metrics
    // These mirror the fields of `AnalysisResult` so we can reconstruct
    // one on tap without re-running the analyzer.

    var transcription: String
    var wordsPerMinute: Double
    var paceLabel: String
    var averageAmplitudeDB: Float
    var volumeLabel: String

    /// Overall pitch score (0...1) computed by
    /// `AnalysisResult.overallScore`. We persist the value (rather
    /// than recomputing it from pace / intonation / articulation on
    /// every read) so the Home view can average it across the
    /// latest N recordings with a single `@Query`, without having
    /// to re-derive it from the three inputs.
    var overallScore: Float

    /// Persisted F0 samples (Hz per chunk) — drives the Intonation
    /// detail chart. Empty array is a valid value (silent recording).
    var pitchSamples: [Float]

    var pitchVariance: Float
    var intonationLabel: String

    /// Persisted RMS amplitude samples (dB per chunk) — drives the
    /// Volume / waveform chart.
    var amplitudeSamples: [Float]

    var articulationScore: Float

    /// Persisted pronunciation issues for the Articulation detail /
    /// Unclear Words screens. Encoded as JSON because
    /// `PronunciationIssue` is a non-trivial value type with nested
    /// `PronunciationExampleSentence` and is not directly
    /// SwiftData-storable.
    var pronunciationIssuesData: Data

    /// Intonation highlight window — best 10–20s segment of the
    /// recording for "Varied" intonation. Optional; nil if the
    /// recording was too short / had no voiced samples.
    var intonationHighlightStart: Double?
    var intonationHighlightDuration: Double?

    /// Pace highlight window — section of the recording closest to
    /// ideal WPM. Optional; nil if the recording was too short.
    var paceHighlightStart: Double?
    var paceHighlightDuration: Double?

    /// Path (relative to the app's Documents directory) of the saved
    /// audio file. Storing a relative path keeps the database valid
    /// across app updates where the container path may change.
    var audioFileRelativePath: String?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        duration: TimeInterval,
        issues: [SpeechIssue],
        languageCode: String,
        transcription: String,
        wordsPerMinute: Double,
        paceLabel: String,
        averageAmplitudeDB: Float,
        volumeLabel: String,
        overallScore: Float,
        pitchSamples: [Float],
        pitchVariance: Float,
        intonationLabel: String,
        amplitudeSamples: [Float],
        articulationScore: Float,
        pronunciationIssues: [PronunciationIssue],
        intonationHighlight: AudioHighlightSegment?,
        paceHighlight: AudioHighlightSegment?,
        audioFileRelativePath: String?
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.issueRawValues = issues.map { $0.rawValue }
        self.languageCode = languageCode
        self.transcription = transcription
        self.wordsPerMinute = wordsPerMinute
        self.paceLabel = paceLabel
        self.averageAmplitudeDB = averageAmplitudeDB
        self.volumeLabel = volumeLabel
        self.overallScore = overallScore
        self.pitchSamples = pitchSamples
        self.pitchVariance = pitchVariance
        self.intonationLabel = intonationLabel
        self.amplitudeSamples = amplitudeSamples
        self.articulationScore = articulationScore
        self.pronunciationIssuesData = (try? JSONEncoder().encode(pronunciationIssues)) ?? Data()
        self.intonationHighlightStart = intonationHighlight?.startTime
        self.intonationHighlightDuration = intonationHighlight?.duration
        self.paceHighlightStart = paceHighlight?.startTime
        self.paceHighlightDuration = paceHighlight?.duration
        self.audioFileRelativePath = audioFileRelativePath
    }

    // MARK: - Convenience

    /// Decoded `[SpeechIssue]` for the UI layer. Unknown / removed
    /// raw values are silently filtered out so the schema is
    /// forward-compatible.
    var issues: [SpeechIssue] {
        issueRawValues.compactMap { SpeechIssue(rawValue: $0) }
    }

    /// Decoded `[PronunciationIssue]` for the Articulation detail /
    /// Unclear Words screens. Returns `[]` if the persisted blob is
    /// missing or undecodable (e.g. older records saved before this
    /// field existed).
    var pronunciationIssues: [PronunciationIssue] {
        guard !pronunciationIssuesData.isEmpty else { return [] }
        return (try? JSONDecoder().decode([PronunciationIssue].self, from: pronunciationIssuesData)) ?? []
    }

    /// Reconstructed highlight window for the Intonation detail.
    /// `nil` if the recording was too short or had no voiced samples.
    var intonationHighlight: AudioHighlightSegment? {
        guard let start = intonationHighlightStart,
              let duration = intonationHighlightDuration else { return nil }
        return AudioHighlightSegment(startTime: start, duration: duration)
    }

    /// Reconstructed highlight window for the Pace detail.
    var paceHighlight: AudioHighlightSegment? {
        guard let start = paceHighlightStart,
              let duration = paceHighlightDuration else { return nil }
        return AudioHighlightSegment(startTime: start, duration: duration)
    }

    /// Absolute URL for the persisted audio file, or `nil` if the
    /// file is missing (e.g. user cleared the app's Documents
    /// directory, or we never saved one).
    var audioFileURL: URL? {
        guard let audioFileRelativePath else { return nil }
        let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first
        return docs?.appendingPathComponent(audioFileRelativePath)
    }

    /// Reconstruct the in-memory `AnalysisResult` shape that the rest
    /// of the app (ReviewSummaryView + all review screens) already
    /// expects. The History list passes one of these to
    /// `AppRoute.reviewSummary` when the user taps a row.
    ///
    /// We stamp `id: self.id` so downstream screens (in particular
    /// `ReviewSummaryView`) can use `result.id` to look this model
    /// back up via the shared `ModelContext` and persist edits
    /// (e.g. title changes) back to SwiftData.
    func toAnalysisResult() -> AnalysisResult {
        AnalysisResult(
            id: id,
            transcription: transcription,
            duration: duration,
            wordsPerMinute: wordsPerMinute,
            paceLabel: paceLabel,
            averageAmplitudeDB: averageAmplitudeDB,
            volumeLabel: volumeLabel,
            pitchSamples: pitchSamples,
            pitchVariance: pitchVariance,
            intonationLabel: intonationLabel,
            amplitudeSamples: amplitudeSamples,
            articulationScore: articulationScore,
            pronunciationIssues: pronunciationIssues,
            audioFileURL: audioFileURL,
            intonationHighlight: intonationHighlight,
            paceHighlight: paceHighlight
        )
    }
}
