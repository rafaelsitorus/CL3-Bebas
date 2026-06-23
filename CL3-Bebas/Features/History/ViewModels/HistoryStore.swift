//
//  HistoryStore.swift
//  CL3-Bebas
//
//  Thin SwiftData wrapper. The actual persisted rows live in
//  `RecordingHistoryModel` and are queried by `HistoryView` via
//  `@Query`. This type exposes the only side-effects the rest of the
//  app needs:
//    - `save(result:languageCode:title:)` — call it once a recording finishes
//      analysis and a new row will appear at the top of the History
//      list.
//    - `rename(model:to:)` — call it when the user edits a recording's
//      title on `ReviewSummaryView`, so the change persists across
//      launches and shows up in the History list immediately.
//
//  We keep `HistoryStore` around (instead of calling
//  `modelContext.insert` from `AppRootView` directly) so:
//    1. The "save a recording" responsibility is owned by the
//       History feature, not the App root.
//    2. Future side-effects (e.g. enqueueing an upload, emitting an
//       analytics event) have a single place to live.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class HistoryStore: ObservableObject {

    /// The `ModelContext` the store writes through. Wired up
    /// lazily — see `configure(modelContext:)` — because the
    /// SwiftUI environment is not available when `@StateObject`
    /// initialises the store.
    private var modelContext: ModelContext?

    init() {
        // Intentionally empty — the `ModelContext` is injected via
        // `configure(modelContext:)` from `AppRootView` once the
        // SwiftUI environment is up.
    }

    /// Late-binding hook so the store can pick up the shared
    /// `ModelContext` after `@StateObject` has already created it.
    /// Idempotent: calling it twice with the same context is a
    /// no-op, and we only ever replace the context with the same
    /// value the SwiftUI environment provides.
    func configure(modelContext: ModelContext) {
        if self.modelContext !== modelContext {
            self.modelContext = modelContext
        }
    }

    // MARK: - Save

    /// Insert a new `RecordingHistoryModel` for the given analysis
    /// result.
    ///
    /// We translate the in-memory `AnalysisResult` (produced by
    /// `SpeechAnalyzer.analyze(...)`) into the persisted entity and
    /// also copy the freshly-recorded audio file from
    /// `FileManager.default.temporaryDirectory` into the app's
    /// Documents directory so it survives across launches — the
    /// original `.caf` lives in the temp dir and would be purged by
    /// iOS at any time.
    ///
    /// `languageCode` is "en" or "id" (matches what
    /// `AppRootView` already extracts from `PitchLanguage`).
    /// `requestedTitle` is the editable title from the recording
    /// language-selection screen.
    @discardableResult
    func save(
        result: AnalysisResult,
        languageCode: String,
        title requestedTitle: String? = nil
    ) -> RecordingHistoryModel? {
        // Refuse to save if the `ModelContext` has not been wired
        // yet — this should never happen in practice because
        // `AppRootView` calls `configure(modelContext:)` before
        // `save(...)`, but we guard it so a misuse never crashes.
        guard let modelContext else {
            print("⚠️ HistoryStore.save called before configure(modelContext:)")
            return nil
        }

        // 1. Copy the recorded audio into Documents (so it persists).
        let savedAudioPath = persistAudioFile(from: result.audioFileURL)

        // 2. Derive the [SpeechIssue] badge list from the analysis.
        let issues = deriveIssues(from: result)

        // 3. Pick a display title. Prefer the editable title from
        //    the language-selection screen, falling back to a
        //    sequential SwiftData count for empty titles.
        let existingCount = (try? modelContext.fetchCount(
            FetchDescriptor<RecordingHistoryModel>()
        )) ?? 0
        let fallbackTitle = "Recording \(existingCount + 1)"
        let trimmedTitle = requestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle

        // 4. Build + insert the model. We pass through EVERY field
        //    of `AnalysisResult` that any downstream review screen
        //    reads — if a field is missing here, screens like
        //    Intonation / Pace / Articulation / Unclear Words will
        //    render empty when the user re-opens a recording from
        //    History. We also persist the derived `overallScore`
        //    (same formula as `AnalysisResult.overallScore`) so the
        //    Home view can average it across the latest recordings
        //    without re-deriving it from the three inputs.
        let model = RecordingHistoryModel(
            title: title,
            date: Date(),
            duration: result.duration,
            issues: issues,
            languageCode: languageCode,
            transcription: result.transcription,
            wordsPerMinute: result.wordsPerMinute,
            paceLabel: result.paceLabel,
            averageAmplitudeDB: result.averageAmplitudeDB,
            volumeLabel: result.volumeLabel,
            overallScore: Self.overallScore(from: result),
            pitchSamples: result.pitchSamples,
            pitchVariance: result.pitchVariance,
            intonationLabel: result.intonationLabel,
            amplitudeSamples: result.amplitudeSamples,
            articulationScore: result.articulationScore,
            pronunciationIssues: result.pronunciationIssues,
            intonationHighlight: result.intonationHighlight,
            paceHighlight: result.paceHighlight,
            audioFileRelativePath: savedAudioPath
        )

        modelContext.insert(model)

        do {
            try modelContext.save()
        } catch {
            print("⚠️ HistoryStore.save failed: \(error)")
            return nil
        }

        return model
    }

    // MARK: - Rename

    /// Persist a user-edited title back to the SwiftData row.
    ///
    /// Called from `ReviewSummaryView` whenever the user finishes
    /// editing the title (`.onSubmit`, focus loss, etc.). The
    /// `ModelContext` lives in this store, so callers don't need
    /// direct access to it. Returns the updated `title` (or the
    /// original value if the rename was rejected).
    @discardableResult
    func rename(model: RecordingHistoryModel, to newTitle: String) -> String {
        // Refuse empty / whitespace-only titles — fall back to the
        // current title so the user never sees a blank History row.
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return model.title
        }
        guard let modelContext else {
            print("⚠️ HistoryStore.rename called before configure(modelContext:)")
            return model.title
        }

        // No-op if the title hasn't actually changed.
        if model.title == trimmed {
            return model.title
        }

        model.title = trimmed

        do {
            try modelContext.save()
        } catch {
            print("⚠️ HistoryStore.rename failed: \(error)")
        }

        return model.title
    }

    // MARK: - Audio persistence

    /// Copy the freshly-recorded audio file from the temp dir into
    /// the app's Documents directory and return the path RELATIVE to
    /// Documents (the format `RecordingHistoryModel` stores).
    ///
    /// Returns `nil` if there's nothing to copy or the copy fails.
    private func persistAudioFile(from sourceURL: URL?) -> String? {
        guard let sourceURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }
        guard let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        // Generate a unique filename so multiple recordings never
        // overwrite each other. We keep the original `.caf`
        // extension so the audio engine can re-open it later.
        let fileName = "recording-\(UUID().uuidString).caf"
        let destination = docs.appendingPathComponent(fileName)

        do {
            // Remove any pre-existing file at the destination (should
            // never happen with a UUID filename, but be defensive).
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return fileName
        } catch {
            print("⚠️ Failed to persist audio file: \(error)")
            return nil
        }
    }

    // MARK: - Derived metric

    /// Same formula as `AnalysisResult.overallScore` (articulation
    /// 40 % + pace 30 % + intonation 30 %) so the persisted
    /// `RecordingHistoryModel.overallScore` matches what the
    /// `ReviewSummary` screen shows the user at save-time.
    ///
    /// We extract it here as a static helper instead of using
    /// `result.overallScore` directly because `overallScore` is
    /// declared as a computed property on `AnalysisResult` —
    /// calling it from a static context is awkward and we want the
    /// formula to live in one place (this file) so the value
    /// persisted to SwiftData and the value displayed to the user
    /// stay in lockstep.
    static func overallScore(from result: AnalysisResult) -> Float {
        let paceScore: Float
        switch result.paceLabel {
        case "Ideal":          paceScore = 1.0
        case "Normal":         paceScore = 0.85
        case "Fast", "Slow":   paceScore = 0.65
        case "Too Fast",
             "Too Slow":       paceScore = 0.35
        default:               paceScore = 0.5
        }

        let intonationScore: Float =
            result.intonationLabel.localizedCaseInsensitiveContains("varied") ? 1.0 : 0.5

        return result.articulationScore * 0.4
             + paceScore * 0.3
             + intonationScore * 0.3
    }

    // MARK: - Issue derivation

    /// Translate an `AnalysisResult` into the badge list the
    /// `HistoryCard` already knows how to render. The mapping is:
    ///   - `intonationLabel == "Flat"`            → `.intonation`
    ///   - `paceLabel` is "Too Fast" / "Too Slow" / "Fast" / "Slow" → `.pace`
    ///   - `volumeLabel == "Too Quiet" / "Too Loud"` → `.volume`
    ///   - `articulationScore < 0.55`             → `.articulation`
    private func deriveIssues(from result: AnalysisResult) -> [SpeechIssue] {
        var issues: [SpeechIssue] = []

        if result.intonationLabel.localizedCaseInsensitiveContains("flat") {
            issues.append(.intonation)
        }

        let pace = result.paceLabel.lowercased()
        if pace.contains("too fast") || pace.contains("too slow")
            || pace == "fast" || pace == "slow" {
            issues.append(.pace)
        }

        let volume = result.volumeLabel.lowercased()
        if volume.contains("too quiet") || volume.contains("too loud") {
            issues.append(.volume)
        }

        if result.articulationScore < 0.55 {
            issues.append(.articulation)
        }

        return issues
    }
}
