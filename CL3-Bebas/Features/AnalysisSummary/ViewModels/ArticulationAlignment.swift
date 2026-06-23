//
//  ArticulationAlignment.swift
//  CL3-Bebas
//
//  Character-level alignment between the acoustic transcript (Wav2Vec2
//  CTC, the "honest listener") and the reference transcript
//  (SFSpeechRecognizer, the "rapi" version with internal LM).
//
//  Pipeline (dual-path, as described in design doc):
//
//  1. Both transcripts are lowercased and concatenated into flat strings.
//  2. LCS (Longest Common Subsequence) alignment finds character-level
//     matching blocks between the two strings.
//  3. Using the char-level mapping we determine which ACOUSTIC WORDS
//     cover which REFERENCE WORDS.
//  4. For each acoustic word, we compute normalized Levenshtein
//     similarity against the COMBINED reference words it covers.
//     This handles CTC word-boundary merging (e.g. "halnam" for
//     "halo nama") — the combined ref "halonama" compares fairly
//     against the merged acoustic "halnam".
//  5. Each covered reference word inherits the acoustic word's
//     decision. If a reference word is covered by multiple acoustic
//     words, it takes the best (highest similarity) one.
//  6. Reference words outside the acoustic model's time window
//     (default: first 5 seconds) are excluded from assessment.
//

import Foundation
import Speech

// MARK: - Public types

enum ArticulationDecision: String, Hashable {
    case match
    case mispronounced
    case unknownName
}

/// One per reference word. The alignment layer produces these; the
/// `PronunciationIssue` list in `ArticulationPipelineSpeech` is built
/// from the subset whose `decision == .mispronounced`.
struct WordAssessment: Hashable {
    let acousticWord: String
    let acousticConfidence: Float
    let referenceWord: String?   // the reference form (for display)
    let referenceSubstring: String  // combined reference text used for comparison
    let similarity: Float        // 0...1, normalized Levenshtein
    let decision: ArticulationDecision
}

// MARK: - SequenceMatcher (port of difflib)

/// One block of contiguous matching characters between the reference
/// and the hypothesis.
struct MatchBlock: Hashable {
    let referenceRange: Range<Int>
    let hypothesisRange: Range<Int>

    var size: Int { referenceRange.count }
}

enum SequenceMatcher {

    /// Return the list of matching blocks between two strings using
    /// the classic LCS-based "Gestalt" algorithm.
    static func matchingBlocks(reference: String, hypothesis: String) -> [MatchBlock] {
        let a = Array(reference)
        let b = Array(hypothesis)
        let n = a.count
        let m = b.count
        guard n > 0 || m > 0 else { return [] }

        var dp = [Int](repeating: 0, count: (n + 1) * (m + 1))
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if a[i] == b[j] {
                    dp[i * (m + 1) + j] = dp[(i + 1) * (m + 1) + (j + 1)] + 1
                } else {
                    let down = dp[(i + 1) * (m + 1) + j]
                    let right = dp[i * (m + 1) + (j + 1)]
                    dp[i * (m + 1) + j] = max(down, right)
                }
            }
        }

        var blocks: [MatchBlock] = []
        var i = 0
        var j = 0
        while i < n && j < m {
            if a[i] == b[j] {
                let startA = i
                let startB = j
                while i < n && j < m && a[i] == b[j] {
                    i += 1
                    j += 1
                }
                blocks.append(MatchBlock(
                    referenceRange: startA..<i,
                    hypothesisRange: startB..<j
                ))
            } else if dp[(i + 1) * (m + 1) + j] >= dp[i * (m + 1) + (j + 1)] {
                i += 1
            } else {
                j += 1
            }
        }
        return blocks
    }
}

// MARK: - Levenshtein

enum EditDistance {

    /// Iterative Wagner–Fischer with two rolling rows.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        let ac = Array(a)
        let bc = Array(b)
        if ac.count > bc.count {
            return levenshtein(b, a)
        }
        let m = ac.count
        let n = bc.count

        var prev = [Int](repeating: 0, count: m + 1)
        var curr = [Int](repeating: 0, count: m + 1)
        for i in 0...m { prev[i] = i }

        for j in 1...n {
            curr[0] = j
            for i in 1...m {
                let cost = ac[i - 1] == bc[j - 1] ? 0 : 1
                curr[i] = min(
                    curr[i - 1] + 1,         // insertion
                    prev[i] + 1,             // deletion
                    prev[i - 1] + cost       // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }

    /// Normalized Levenshtein similarity in `[0, 1]`.
    static func similarity(_ a: String, _ b: String) -> Float {
        if a.isEmpty && b.isEmpty { return 1.0 }
        let longer = max(a.count, b.count)
        if longer == 0 { return 1.0 }
        let dist = levenshtein(a, b)
        return Float(longer - dist) / Float(longer)
    }

    /// Score in `[0, 1]` measuring how much the shorter string appears
    /// inside the longer one as a contiguous substring. Used to detect
    /// Wav2Vec2 CTC word-merge cases: the model collapses adjacent
    /// words into one token (e.g. "my next" → "MYNE", "for us" → "FORUS",
    /// "a practice" → "APRACTIC"). A pure Levenshtein score treats the
    /// merged form as low-similarity; the containment score gives
    /// credit when one is a substring of the other, scaled by the
    /// length of the shorter string relative to the longer one (so
    /// "art" inside "EARTHLESION" is 3/11 ≈ 0.27, not a perfect 1.0).
    ///
    /// Returns 0 when neither string contains the other.
    static func containmentSimilarity(_ a: String, _ b: String) -> Float {
        if a.isEmpty || b.isEmpty { return 0 }
        let shorter = a.count <= b.count ? a : b
        let longer  = a.count <= b.count ? b : a
        guard longer.contains(shorter) else { return 0 }
        return Float(shorter.count) / Float(longer.count)
    }
}

// MARK: - Word-level alignment (the actual pipeline)

enum ArticulationAlignment {

    // ── Three-category system ─────────────────────────────────────
    //
    // Category 1 — MATCH (Bagus):
    //   sim >= 0.25. The acoustic model heard something recognizable.
    //   Even if the transcription isn't perfect (e.g. "perabawa" for
    //   "Prabowo"), the speaker pronounced it clearly enough that the
    //   model could pick it up.
    //
    // Category 2 — MISPRONOUNCED (Jelek):
    //   ONLY genuine mumbling: the acoustic model detected the word
    //   (confidence > 0) but the speaker was so unclear that
    //   confidence dropped below the mumbling floor (0.20).
    //   This is the ONLY case that appears on the "Unclear Words"
    //   page. False positives from model noise are eliminated.
    //
    // Category 3 — UNKNOWN NAME (Nama diluar dictionary):
    //   Everything else: not detected (sim=0.0), foreign names,
    //   loanwords, short function words the CTC model dropped,
    //   chunk boundary artifacts. These are EXCLUDED from scoring
    //   so they don't penalize the speaker.

    /// Similarity at or above this → word pronounced correctly.
    static let matchThreshold: Float = 0.25

    /// Acoustic confidence below this → genuine mumbling.
    /// Only triggers when confidence > 0 (i.e. the model detected
    /// something, but it was very unclear). When confidence == 0,
    /// the word was simply not detected (unknownName, not mumbling).
    static let acousticConfidenceFloor: Float = 0.20

    static func bandDecision(similarity: Float, acousticConfidence: Float) -> ArticulationDecision {
        // ── Category 2: Mumbling (Jelek) ────────────────────────
        // The model detected the word (conf > 0) but the speaker
        // was genuinely unclear (conf < floor). This is the ONLY
        // condition that counts as "bad articulation".
        if acousticConfidence > 0 && acousticConfidence < acousticConfidenceFloor {
            return .mispronounced
        }

        // ── Category 1: Match (Bagus) ───────────────────────────
        // The model heard something recognizable. Give the speaker
        // the benefit of the doubt.
        if similarity >= matchThreshold { return .match }

        // ── Category 3: Unknown Name (Diluar dictionary) ────────
        // Everything else: not detected (sim=0.0), foreign names,
        // model noise, short words the CTC model dropped.
        // Excluded from scoring — don't penalize the speaker.
        return .unknownName
    }

    // MARK: - Top-level entry point

    /// Align the acoustic transcript against the reference segments
    /// using TIME-AWARE matching.
    ///
    /// The algorithm:
    /// 1. Convert each acoustic word's frame indices to a timestamp (seconds).
    /// 2. For each reference word (SFSpeech segment), find the BEST
    ///    acoustic word whose time overlaps within ±2 seconds.
    /// 3. Compute normalized Levenshtein similarity between the acoustic
    ///    word and the reference word.
    /// 4. Apply the three-category decision.
    ///
    /// This prevents the old bug where LCS would match acoustic words
    /// from the first 5-second chunk to reference words from minute 2.
    static func run(
        refSegments: [SFTranscriptionSegment],
        acoustic: AcousticTranscript,
        languageCode: String,
        recordingDuration: TimeInterval = 30.0
    ) -> [WordAssessment] {
        guard !acoustic.words.isEmpty else { return [] }

        // Clean reference words: strip punctuation, split multi-word
        // segments into individual words, keep words > 1 char.
        // Track the timestamp of each word for time-alignment.
        struct RefWord {
            let text: String
            let timestamp: TimeInterval  // seconds into the recording
        }

        let refWords: [RefWord] = refSegments.flatMap { seg -> [RefWord] in
            let words = seg.substring
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
                .split(separator: " ")
                .map { String($0) }
                .filter { $0.count > 1 }
            return words.map { RefWord(text: $0, timestamp: TimeInterval(seg.timestamp)) }
        }
        guard !refWords.isEmpty else { return [] }

        // ── Convert acoustic frame indices to timestamps ────────────
        // Use the ACTUAL recording duration (not SFSpeech segment
        // timestamps, which may only cover a fraction of the recording).
        // Acoustic frame indices span [0, totalFrames] linearly across
        // the entire recording duration.
        let totalFrames = max(1, acoustic.framesProcessed)
        let audioDuration = max(recordingDuration, 5.0)

        struct TimedAcousticWord {
            let word: AcousticWord
            let estimatedTime: TimeInterval
        }

        let timedAcousticWords: [TimedAcousticWord] = acoustic.words.map { w in
            let midFrame = Double(w.frameStart + w.frameEnd) / 2.0
            let timeFraction = midFrame / Double(totalFrames)
            let estimatedTime = timeFraction * audioDuration
            return TimedAcousticWord(word: w, estimatedTime: estimatedTime)
        }

        // ── Filter CTC fragments ─────────────────────────────────────
        // The Wav2Vec2 CTC decoder produces hallucinated tokens at
        // non-speech boundaries (silence, breath, the chunk seam).
        // These come in three flavours we can drop reliably:
        //   * Very short words (1 char) — almost never real speech
        //   * Short words with mid confidence — fragments the model is
        //     unsure about ("ng", "sa")
        //   * Long words dominated by repeated characters — CTC
        //     collapse over a noise-only region produces strings like
        //     "ubusemusemamama" or "sekaabumaabisbusekeabpsustelag"
        // Dropping these keeps them out of the candidate pool so a
        // real ref word is matched to a real acoustic word instead.
        let candidates: [TimedAcousticWord] = timedAcousticWords.filter { tw in
            let text = tw.word.text
            let conf = tw.word.confidence
            if text.count < 2 { return false }
            if text.count < 3 && conf < 0.85 { return false }
            if Self.hasRepeatedCharacterRun(text) { return false }
            return true
        }
        let dropped = timedAcousticWords.filter { tw in !candidates.contains(where: { $0.word.text == tw.word.text && $0.estimatedTime == tw.estimatedTime }) }
        if !dropped.isEmpty {
            print("🔗 dropped \(dropped.count) fragment acoustic words: \(dropped.map { "'\($0.word.text)'" })")
        }

        print("🔗 time mapping: \(candidates.count) acoustic words over \(String(format: "%.1f", audioDuration))s, \(refWords.count) ref words")
        for tw in candidates.prefix(5) {
            print("🔗   acoustic '\(tw.word.text)' @ \(String(format: "%.1f", tw.estimatedTime))s")
        }
        for rw in refWords.prefix(5) {
            print("🔗   ref '\(rw.text)' @ \(String(format: "%.1f", rw.timestamp))s")
        }

        // ── Monotonic sequential alignment ──────────────────────────
        // Walk both lists forward in time order. Each ref word picks
        // the highest-similarity acoustic word within a small forward
        // lookahead, and the acoustic cursor only moves forward — so a
        // later ref word can never re-match an earlier acoustic word.
        //
        // Why this matters: the previous "best in ±3s window" search
        // let later ref words steal earlier acoustic words when the
        // similarity happened to be a touch better, producing visible
        // drift (e.g. "dan" matched to "bantu", "bisa" matched to
        // "seiga" while the right acoustic words were still ahead in
        // the candidate list).
        let jumpBackTolerance: TimeInterval = 2.0
        let lookahead: Int = 5
        let minCandidateSim: Float = 0.20

        var assessments: [WordAssessment] = []
        var acIdx = 0

        for refWord in refWords {
            // Find the first candidate whose estimated time is at or
            // after the ref word's time (with a small backward grace
            // period so we don't skip a candidate that landed just
            // before the ref boundary).
            var searchStart = acIdx
            while searchStart < candidates.count
                    && candidates[searchStart].estimatedTime < refWord.timestamp - jumpBackTolerance {
                searchStart += 1
            }
            if searchStart >= candidates.count {
                // No acoustic word left in the timeline → unknownName
                assessments.append(WordAssessment(
                    acousticWord: "—",
                    acousticConfidence: 0.0,
                    referenceWord: refWord.text,
                    referenceSubstring: "",
                    similarity: 0.0,
                    decision: .unknownName
                ))
                continue
            }

            // Within the next `lookahead` candidates, pick the one with
            // the highest similarity to the current ref word. We use
            // the MAX of Levenshtein similarity and containment
            // similarity so Wav2Vec2 CTC word-merge cases (e.g. the
            // model collapsing "my next" into "MYNE" or "a practice"
            // into "APRACTIC") still score well when the ref word
            // appears as a substring of the merged acoustic word.
            let windowEnd = min(candidates.count, searchStart + lookahead)
            var bestSim: Float = -1
            var bestPick: Int? = nil
            for k in searchStart..<windowEnd {
                let ref = normalize(refWord.text)
                let hyp = normalize(candidates[k].word.text)
                let lev = EditDistance.similarity(ref, hyp)
                let con = EditDistance.containmentSimilarity(ref, hyp)
                let sim = max(lev, con)
                if sim > bestSim {
                    bestSim = sim
                    bestPick = k
                }
            }

            if let pick = bestPick, bestSim >= minCandidateSim {
                let acWord = candidates[pick].word
                let ref = normalize(refWord.text)
                let hyp = normalize(acWord.text)
                // Use max(Levenshtein, containment) so word-merge
                // candidates that contain the ref word score the same
                // way they did at pick time (no surprise demotion).
                let trueSim = max(
                    EditDistance.similarity(ref, hyp),
                    EditDistance.containmentSimilarity(ref, hyp)
                )
                let decision = bandDecision(
                    similarity: trueSim,
                    acousticConfidence: acWord.confidence
                )
                assessments.append(WordAssessment(
                    acousticWord: acWord.text,
                    acousticConfidence: acWord.confidence,
                    referenceWord: refWord.text,
                    referenceSubstring: acWord.text,
                    similarity: trueSim,
                    decision: decision
                ))
                // Advance the cursor past the chosen candidate so the
                // same acoustic word can't be matched twice.
                acIdx = pick + 1
            } else {
                // No good candidate in the lookahead → unknownName
                assessments.append(WordAssessment(
                    acousticWord: "—",
                    acousticConfidence: 0.0,
                    referenceWord: refWord.text,
                    referenceSubstring: "",
                    similarity: 0.0,
                    decision: .unknownName
                ))
            }
        }

        // ── Debug output ────────────────────────────────────────────
        let mispronouncedCount = assessments.filter { $0.decision == .mispronounced }.count
        print("🔗 alignment[\(languageCode)]: \(assessments.count) ref words, \(mispronouncedCount) mispronounced")
        for (i, a) in assessments.enumerated() {
            let tag = a.decision == .match ? "✅" : (a.decision == .mispronounced ? "❌" : "⏭️")
            print("🔗   [\(i)] \(tag) ref=\"\(a.referenceWord ?? "")\" acoustic=\"\(a.acousticWord)\" sim=\(String(format: "%.2f", a.similarity)) conf=\(String(format: "%.2f", a.acousticConfidence)) → \(a.decision.rawValue)")
        }
        return assessments
    }

    // MARK: - Helpers

    /// Lowercase + strip non-alphanumeric + collapse spaces.
    /// Used for similarity comparison only.
    private static func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
        let scalars = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " "
        }
        let filtered = String(String.UnicodeScalarView(scalars))
        return filtered.split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: "")
    }

    /// True when a meaningful fraction of `word` is taken up by runs
    /// of the same character repeated 3+ times. Used to detect CTC
    /// hallucinations at non-speech boundaries (e.g. "ubusemusemamama",
    /// "sekaabumaabisbusekeabpsustelag") — these are produced when the
    /// model has no real audio to decode and just loops on a token.
    ///
    /// The threshold (40% of the string being a 3+ run) is loose enough
    /// not to flag legitimate words with one repeated syllable
    /// ("pepaya", "massa") but tight enough to catch the patterns the
    /// CTC decoder actually emits at boundaries.
    private static func hasRepeatedCharacterRun(_ word: String) -> Bool {
        let chars = Array(word.lowercased())
        guard chars.count >= 6 else { return false }
        var repeatedChars = 0
        var i = 0
        while i < chars.count {
            var runLen = 1
            while i + runLen < chars.count && chars[i + runLen] == chars[i] {
                runLen += 1
            }
            if runLen >= 3 {
                repeatedChars += runLen
            }
            i += runLen
        }
        return repeatedChars * 10 >= chars.count * 4
    }
}
