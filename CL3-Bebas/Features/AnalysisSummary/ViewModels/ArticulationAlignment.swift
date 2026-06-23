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

    /// Score in `[0, 1]` measuring how much of `a` appears inside `b`
    /// as a SUBSEQUENCE (not necessarily contiguous). Used as a
    /// character-level fallback when a ref word was clearly spoken but
    /// the CTC decoder inserted/deleted a few characters, e.g. acoustic
    /// "kitaa" for ref "kita" (extra 'a'), or acoustic "disubelah"
    /// (CTC merge of "di" + "sebelah") where ref "di" still appears
    /// cleanly as a prefix.
    ///
    /// Scoring rules:
    /// - All of `a` matched inside `b` → return `ref.count / hyp.count`
    ///   so a clean subsequence inside a short hyp (e.g. "di" inside
    ///   "di" → 1.0) scores high, while a clean subsequence inside a
    ///   long merged hyp (e.g. "di" inside "disubelah" → 2/9 ≈ 0.22)
    ///   is still rewarded but at the cost of the extra acoustic
    ///   material that the model merged in.
    /// - Partial match (more than half of `a`'s chars present in order
    ///   but not all of them) → use `(matched/ref.count)^2 * (matched/hyp.count)`
    ///   so partial matches are gently scored but never above 1.0 and
    ///   never compete with a clean containment hit.
    /// - Less than half of `a`'s chars matched → return 0.
    static func subsequenceSimilarity(_ a: String, _ b: String) -> Float {
        let ac = Array(a.lowercased())
        let bc = Array(b.lowercased())
        if ac.isEmpty || bc.isEmpty { return 0 }

        // Walk the ref through hyp, counting how many ref chars appear
        // in order. Greedy, O(n+m), good enough to spot "the ref word
        // is in there somewhere" without a full LCS table.
        var i = 0
        var matched = 0
        for ch in bc {
            if i < ac.count && ch == ac[i] {
                matched += 1
                i += 1
            }
        }
        let minMatched = (ac.count + 1) / 2
        if matched < minMatched { return 0 }

        let hypCoverage = Float(matched) / Float(bc.count)
        if matched == ac.count {
            // Full subsequence match — every ref char appears in
            // order inside hyp, just not necessarily contiguously.
            // This is the strongest signal the user actually said
            // the word and the CTC decoder just merged it with a
            // neighbour. We trust it at full credit: the user spoke
            // the word clearly, the model's string output just
            // over-extended across the boundary.
            //
            // Example wins:
            //   "di"   inside "disubelah" → 1.0
            //   "saya" inside "sayaora"   → 1.0
            //   "hijau" inside a longer merge → 1.0
            return 1.0
        }
        // Partial subsequence — square the ref coverage to penalise
        // incomplete matches more harshly than Levenshtein would.
        let refCoverage = Float(matched) / Float(ac.count)
        return refCoverage * refCoverage * hypCoverage
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
    /// 0.45 is calibrated for the Wav2Vec2-ID model used here,
    /// which routinely produces string-level noise like
    /// "purtunya" for "Fotonya" (lev 0.50) and "mira" for "merah"
    /// (lev 0.60). The model is hearing the right phonemes but
    /// emitting them with different character substitutions —
    /// phonetic normalization in `normalize(...)` brings the
    /// scores up; this threshold then accepts the surviving
    /// borderline matches. Going higher (0.55-0.65) flags every
    /// correctly-spoken word as unknown because the model output
    /// is never string-identical to the reference.
    ///
    /// Containment similarity is folded in (see `run(...)`),
    /// which can lift a low Levenshtein score when the ref word
    /// appears as a substring of an acoustic word-merge like
    /// "kamulusecepat" — that's intentional, those merges are
    /// legitimate CTC output for fluent speech.
    static let matchThreshold: Float = 0.45

    /// Acoustic confidence below this → genuine mumbling.
    /// Only triggers when confidence > 0 (i.e. the model detected
    /// something, but it was very unclear). When confidence == 0,
    /// the word was simply not detected (unknownName, not mumbling).
    /// 0.50 is the "model is unsure" floor — values like 0.78-0.86
    /// that we see on borderline words in the wild still count as
    /// detected speech, just not confident enough to be a match.
    static let acousticConfidenceFloor: Float = 0.50

    /// Borderline-similarity floor. When a candidate has sim in
    /// [borderlineSimFloor, matchThreshold) AND low-ish acoustic
    /// confidence, we surface it as mispronounced instead of
    /// unknownName — the model heard something at that position
    /// but didn't match it cleanly, which is a real signal worth
    /// showing to the speaker.
    static let borderlineSimFloor: Float = 0.30

    /// Acoustic confidence ceiling for the borderline rule. Below
    /// this AND above the sim floor → mispronounced. Above this
    /// (very confident acoustic) → unknownName (trust the model).
    static let borderlineConfCeiling: Float = 0.85

    /// How far ABOVE the match threshold a sim can sit while still
    /// being treated as "close but not confident enough to call a
    /// match". Combined with low conf this catches things like
    /// "beliari" (sim 0.57 after phonetic normalisation, conf 0.81)
    /// for ref "blur" — the strings are similar, the model just
    /// wasn't sure, so the user gets useful feedback.
    static let closeMatchBand: Float = 0.20

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

        // ── Category 2b: Borderline Mispronounced (close-but-low) ─
        // Two flavours of borderline:
        //
        // 1. Sim is just under the match threshold (still in the
        //    uncertain range) AND the acoustic model wasn't very
        //    confident. The model heard something but didn't match
        //    it cleanly — the user probably mispronounced the word.
        //
        // 2. Sim is in the "close match" band (just above the match
        //    threshold up to closeMatchBand higher) AND the model
        //    still wasn't confident. The strings look similar after
        //    phonetic normalisation but the model is hedging. Worth
        //    showing the speaker — "blur" vs "beliari" (sim 0.57
        //    after phonetic, conf 0.81) is exactly this case.
        if similarity >= borderlineSimFloor
                && acousticConfidence > 0
                && acousticConfidence < borderlineConfCeiling {
            return .mispronounced
        }
        if similarity >= matchThreshold
                && similarity < matchThreshold + closeMatchBand
                && acousticConfidence > 0
                && acousticConfidence < borderlineConfCeiling {
            return .mispronounced
        }

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
        //
        // 4s jump-back + 8-candidate lookahead gives the alignment
        // enough room to recover from CTC truncation at chunk seams
        // (where a word can land 1-2s before or after where the ref
        // text places it). The cursor still only moves forward, so
        // we don't reintroduce the drift the old global window had.
        let jumpBackTolerance: TimeInterval = 4.0
        let lookahead: Int = 8
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
            // the MAX of Levenshtein similarity, containment
            // similarity, AND subsequence similarity so Wav2Vec2 CTC
            // word-merge cases (e.g. the model collapsing "my next"
            // into "MYNE" or "a practice" into "APRACTIC") still score
            // well, and so inserted characters in the acoustic form
            // don't drop the score to zero for what is actually a
            // recognizable utterance (e.g. acoustic "kitaa" for ref
            // "kita" is subsequence 0.96, not Levenshtein 0.80).
            let windowEnd = min(candidates.count, searchStart + lookahead)
            var bestSim: Float = -1
            var bestPick: Int? = nil
            for k in searchStart..<windowEnd {
                let ref = normalize(refWord.text)
                let hyp = normalize(candidates[k].word.text)
                let lev = EditDistance.similarity(ref, hyp)
                let con = EditDistance.containmentSimilarity(ref, hyp)
                let sub = EditDistance.subsequenceSimilarity(ref, hyp)
                let sim = max(lev, con, sub)
                if sim > bestSim {
                    bestSim = sim
                    bestPick = k
                }
            }

            if let pick = bestPick, bestSim >= minCandidateSim {
                let acWord = candidates[pick].word
                let ref = normalize(refWord.text)
                let hyp = normalize(acWord.text)
                // Use max(Levenshtein, containment, subsequence) so
                // word-merge and insert/duplicate cases score the same
                // way they did at pick time (no surprise demotion).
                let trueSim = max(
                    EditDistance.similarity(ref, hyp),
                    EditDistance.containmentSimilarity(ref, hyp),
                    EditDistance.subsequenceSimilarity(ref, hyp)
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
                // Only advance the cursor past the chosen candidate
                // when the alignment is actually confident — otherwise
                // a borderline match would lock the acoustic word out
                // from being re-tried by the next ref word (which
                // might be the one that actually belongs to it).
                // The cursor stays put on low-similarity picks so the
                // next ref word's lookahead still includes this
                // candidate and can choose it if it's a better fit.
                if trueSim >= matchThreshold {
                    acIdx = pick + 1
                }
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
        let collapsed = filtered.split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: "")

        // ── Indonesian phonetic normalisation ──────────────────────
        // Wav2Vec2-ID routinely emits acoustically-similar chars in
        // place of the reference character:
        //   * f / v / b / p  — all labial consonants (the model hears
        //     "Fotonya" and decodes it as "purtunya" because the
        //     voice onset time and formant transitions are close).
        //   * j / y          — palatal approximant vs. voiced
        //     palatal fricative (the model often hears "ya" as "ja").
        //   * d / t at word
        //     onset          — alveolar stop confusion when there's no
        //     following vowel ("dipamer" → "dipa" / "tipa").
        //   * ng / n        — common nasal allophony.
        //
        // Mapping every member of a confusable set to the same
        // canonical char makes Levenshtein/containment/subsequence
        // comparisons match what the speaker actually said, even
        // when the model's character output looks nothing like the
        // reference string.
        var out = ""
        out.reserveCapacity(collapsed.count)
        for ch in collapsed {
            switch ch {
            case "f", "v", "b", "p": out.append("p")
            case "j", "y":           out.append("y")
            case "d", "t":           out.append("t")
            case "g", "k", "q":      out.append("k")
            case "z", "s", "c":      out.append("s")
            default:                  out.append(ch)
            }
        }
        return out
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
