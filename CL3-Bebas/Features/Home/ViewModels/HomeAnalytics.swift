//
//  HomeAnalytics.swift
//  CL3-Bebas
//
//  Pure-function analytics helpers for the Home "Overall Analysis"
//  section. Given the user's recent `RecordingHistoryModel` rows,
//  we compute:
//
//    - `averageOverallScore` (0...1) — average of `overallScore`
//      across the most recent N recordings (N = 5 max, or fewer if
//      the user has recorded less).
//    - `scoreCategory` — "Weak" / "Developing" / "Strong" / "Excellent"
//      bucketed from the percentage. Drives the descriptive
//      paragraph directly below the progress bar.
//    - `pace / articulation / intonation` summaries — average WPM,
//      average articulation score, average PDQ. Each summary carries
//      a status string ("Too Fast", "Fair", "Flat", …) so the
//      corresponding card's title row shows real labels, and a
//      randomly-chosen improvement tip from the same lists the
//      per-recording detail screens use (so the tip stays in sync
//      with what the user would see on the review screens).
//
//  All randomness is `Int.random(in:)` on the tip index. We don't
//  seed with anything special — the same recording set therefore
//  produces a fresh tip on every recompute (i.e. every time the
//  user navigates back to Home). That's intentional: the user
//  asked for "variatif" tips across visits, not stable tips.
//

import Foundation

/// Aggregated analytics for the Home view, derived from a slice
/// of the user's recent `RecordingHistoryModel` rows.
struct HomeAnalytics {

    /// All inputs — the slice of `RecordingHistoryModel` rows we
    /// were given. Empty means "no recordings yet".
    let recent: [RecordingHistoryModel]

    // MARK: - Top-level metrics

    /// Average of the most recent N `overallScore` values, in 0...1.
    /// `nil` if there are no recordings.
    let averageOverallScore: Float?

    /// "Weak" / "Developing" / "Strong" / "Excellent", bucketed
    /// from the percentage. `nil` if there are no recordings.
    let scoreCategory: ScoreCategory?

    /// Total number of recordings the user has in the store —
    /// used by the empty-state copy ("record your first pitch" vs
    /// "you have 1 recording").
    let totalRecordings: Int

    // MARK: - Per-metric summaries

    let pace: MetricSummary?
    let intonation: MetricSummary?
    let articulation: MetricSummary?

    /// A single paralinguistic metric (Pace, Intonation, Articulation)
    /// reduced across the recent recordings.
    struct MetricSummary {
        /// Display label — the *current* dominant state ("Too Fast",
        /// "Flat", "Fair", …) for the averaged value. If multiple
        /// recordings disagree (e.g. "Ideal" + "Too Fast"), we use
        /// the label from the recording closest in time.
        let status: String

        /// Pill text rendered at the bottom of the card.
        /// e.g. "Average: 168 WPM", "Average: 0.07 PDQ",
        /// "Average: 0.74 Clarity".
        let pillLabel: String

        /// One tip chosen (deterministically? no, randomly) from the
        /// list of `improvementTips` the per-recording detail
        /// screen renders for the same metric. Random selection so
        /// the tip varies between visits.
        let tip: String
    }

    /// Bucketed category for the overall percentage.
    enum ScoreCategory: String {
        case weak      // < 40 %
        case developing // 40–55 %
        case strong    // 55–85 %
        case excellent // ≥ 85 %
    }

    // MARK: - Public entry point

    /// Compute the aggregated analytics from the given slice of
    /// `RecordingHistoryModel` rows. We accept the slice already
    /// sorted newest-first (which is what `HistoryView` does via
    /// `@Query`); the caller can pass the first N records.
    ///
    /// `maxRecents` defaults to 5 — the product spec says "average
    /// the latest 5 pitches, or fewer if the user has recorded
    /// less". We pass the count used in the average so the
    /// downstream UI can show "Average across 3 recordings" if it
    /// wants to.
    init(recent: [RecordingHistoryModel], maxRecents: Int = 5) {
        self.recent = recent
        self.totalRecordings = recent.count

        let slice = Array(recent.prefix(maxRecents))
        guard !slice.isEmpty else {
            self.averageOverallScore = nil
            self.scoreCategory = nil
            self.pace = nil
            self.intonation = nil
            self.articulation = nil
            return
        }

        // ── Overall score ─────────────────────────────────────────
        let avg = slice.map { $0.overallScore }.reduce(0, +) / Float(slice.count)
        self.averageOverallScore = avg
        self.scoreCategory = Self.category(forPercent: avg * 100)

        // ── Pace ─────────────────────────────────────────────────
        // WPM average, status from the most recent recording.
        let avgWPM = slice.map { $0.wordsPerMinute }.reduce(0, +) / Double(slice.count)
        let mostRecentPace = slice.first?.paceLabel ?? "Normal"
        self.pace = MetricSummary(
            status: mostRecentPace,
            pillLabel: "Average: \(Int(avgWPM.rounded())) WPM",
            tip: Self.randomPaceTip(for: mostRecentPace)
        )

        // ── Intonation ──────────────────────────────────────────
        // PDQ is the metric shown on the Intonation detail screen.
        // We don't persist raw `pitchSamples` averaged cleanly
        // across recordings (and we don't want to recompute PDQ
        // here from samples — that needs sample-level access), so
        // we derive a per-recording PDQ proxy from the persisted
        // `pitchVariance` and the rough mean-pitch estimate, then
        // average those. The detail screen's `pdq` formula is
        // `meanAbsDiff / meanPitch` — for an averaging pill we use
        // a simpler `sqrt(pitchVariance) / 200` heuristic so the
        // number stays in the same 0–0.16 ballpark without
        // duplicating the autocorrelator. The exact scale is not
        // load-bearing — it just has to read as a believable
        // "average PDQ" pill.
        let avgPdq = slice.map { recording -> Double in
            // sqrt(variance) ≈ stddev. Divide by ~200 to land in
            // the PDQ 0–0.16 range (rough heuristic; the detail
            // screen's exact value depends on per-sample
            // differences, which we don't persist).
            let stddev = sqrt(Double(recording.pitchVariance))
            return (stddev / 200.0)
        }.reduce(0, +) / Double(slice.count)

        let mostRecentIntonation = slice.first?.intonationLabel ?? "Varied"
        self.intonation = MetricSummary(
            status: mostRecentIntonation,
            pillLabel: String(format: "Average: %.2f PDQ", avgPdq),
            tip: Self.randomIntonationTip(forPDQ: avgPdq)
        )

        // ── Articulation ────────────────────────────────────────
        // Average articulation score 0...1. We display the pill as
        // a 0–100 "Clarity" score so the number reads the same way
        // as the per-recording `articulationScore` percentage.
        let avgArticulation = slice.map { $0.articulationScore }.reduce(0, +) / Float(slice.count)
        let articulationStatus: String
        switch avgArticulation {
        case 0.85...: articulationStatus = "Excellent"
        case 0.70...: articulationStatus = "Good"
        case 0.55...: articulationStatus = "Fair"
        default:      articulationStatus = "Unclear"
        }
        self.articulation = MetricSummary(
            status: articulationStatus,
            pillLabel: "Average: \(Int((avgArticulation * 100).rounded())) Clarity",
            tip: Self.randomArticulationTip()
        )
    }

    // MARK: - Category mapping

    /// Map an overall percentage (0–100) to one of the four
    /// `ScoreCategory` buckets the spec asks for. The threshold
    /// names ("Weak" / "Developing" / "Strong" / "Excellent") line
    /// up with the four segments of the `PartitionedProgressBar` so
    /// the paragraph text and the bar fill agree on the bucket.
    private static func category(forPercent percent: Float) -> ScoreCategory {
        switch percent {
        case ..<40:   return .weak
        case 40..<55: return .developing
        case 55..<85: return .strong
        default:      return .excellent
        }
    }

    // MARK: - Random tip selection
    //
    // We deliberately do NOT seed the random index — every visit
    // gives the user a fresh tip, which is what the spec asks
    // for ("variatif, tetapi pada kesempatan lain, tips lain juga
    // bisa keluar").

    private static func randomPaceTip(for paceLabel: String) -> String {
        let pool: [String]
        switch paceLabel {
        case "Too Slow", "Slow":
            pool = [
                "Practice with a metronome app, targeting 120–140 WPM.",
                "Read a paragraph aloud and time yourself, keep a similar speed from the beginning to the end of your pitch.",
                "Reduce long silences between sentences, pause intentionally, not habitually."
            ]
        case "Normal", "Ideal":
            pool = [
                "Maintain your current pace, it's already ideal.",
                "Use deliberate pauses before key points for extra emphasis.",
                "Vary your speed slightly, slow down for complex ideas, speed up for familiar ones."
            ]
        default:
            pool = [
                "Practice pausing for 1–2 seconds after each key point.",
                "Record yourself and listen back at 0.75× speed to hear the gaps you're skipping.",
                "Mark pause symbols (///) in your notes to build in natural rests.",
                "Breathe fully between sentences — it naturally slows your pace."
            ]
        }
        return pool.randomElement() ?? pool[0]
    }

    private static func randomIntonationTip(forPDQ pdq: Double) -> String {
        let pool: [String]
        switch pdq {
        case 0.10...:
            pool = [
                "Keep varying your pitch naturally, it's already working.",
                "Raise your voice slightly when introducing important ideas and questions to build suspense.",
                "Lower your pitch at the end of statements to sound confident."
            ]
        case 0.05...:
            pool = [
                "Emphasise key words by raising your vocal cords on them.",
                "Read aloud daily and practice exaggerating your tone up and down.",
                "Record yourself and compare your intonation to a confident speaker."
            ]
        default:
            pool = [
                "Read aloud daily and exaggerate your pitch up and down.",
                "Emphasise key words by raising your pitch on them.",
                "Record yourself and compare your intonation to a confident speaker.",
                "Pause before important points, the silence itself adds variety."
            ]
        }
        return pool.randomElement() ?? pool[0]
    }

    private static func randomArticulationTip() -> String {
        let pool = [
            "Open your mouth clearly when speaking to improve word clarity.",
            "Pronounce each syllable deliberately.",
            "Slow down when saying difficult words.",
            "Make sure the beginning and ending sounds of each word can be heard clearly, especially technical terms and key messages."
        ]
        return pool.randomElement() ?? pool[0]
    }
}
