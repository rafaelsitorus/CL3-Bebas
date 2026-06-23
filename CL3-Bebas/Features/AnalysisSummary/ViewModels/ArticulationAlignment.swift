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
}

// MARK: - Word-level alignment (the actual pipeline)

enum ArticulationAlignment {

    // ── Threshold bands ──────────────────────────────────────────
    //
    // Lowered from the original 0.80/0.40 to account for CTC
    // character-level noise (word boundary merging, char dropping).
    // The Wav2Vec2 character CTC model reliably catches multi-char
    // mispronunciations (sim < 0.65) but not single-char differences
    // (sim ~0.85). These thresholds are tuned for the production
    // model's noise floor.

    /// Similarity at or above this → word pronounced correctly.
    static let matchThreshold: Float = 0.65

    /// Similarity below this → out-of-vocabulary name/loanword (skip).
    static let unknownNameThreshold: Float = 0.25

    /// Acoustic confidence below this → mumbling, always flag.
    static let acousticConfidenceFloor: Float = 0.25

    /// Time window for the acoustic model. Reference words beyond
    /// this timestamp are excluded from assessment (the Wav2Vec2
    /// model only processes 80 000 samples = 5 seconds at 16 kHz).
    static let acousticWindowSeconds: TimeInterval = 5.0

    static func bandDecision(similarity: Float, acousticConfidence: Float) -> ArticulationDecision {
        // Very low confidence → mumbling → mispronounced
        if acousticConfidence < acousticConfidenceFloor {
            return .mispronounced
        }
        // Good similarity → match
        if similarity >= matchThreshold { return .match }
        // Medium similarity → mispronounced (genuine articulation issue)
        if similarity >= unknownNameThreshold { return .mispronounced }
        // Very low similarity → out-of-vocabulary name/loanword.
        // NOTE: We do NOT override this based on acoustic confidence.
        // Some language models (notably Indonesian Wav2Vec2) produce
        // high-confidence garbage — treating those as "mispronounced"
        // causes 100% false-positive rates.
        return .unknownName
    }

    // MARK: - Top-level entry point

    /// Align the acoustic transcript against the reference segments.
    ///
    /// The algorithm:
    /// 1. Filter reference words to the acoustic model's time window.
    /// 2. Build character-level LCS alignment between lowercased texts.
    /// 3. For each acoustic word, find which reference words it covers
    ///    (via the char mapping) and compute similarity against the
    ///    combined reference text.
    /// 4. For each reference word, take the best covering acoustic
    ///    assessment.
    /// 5. Uncovered reference words are marked as mispronounced.
    static func run(
        refSegments: [SFTranscriptionSegment],
        acoustic: AcousticTranscript,
        languageCode: String
    ) -> [WordAssessment] {
        guard !acoustic.words.isEmpty else { return [] }

        // ── Step 0: Filter reference segments to acoustic window ────
        // The Wav2Vec2 model only processes the first ~5 seconds of
        // audio. Only assess reference words within that window.
        let windowedSegments = refSegments.filter {
            TimeInterval($0.timestamp) < acousticWindowSeconds
        }

        // Clean reference words: strip punctuation, split multi-word
        // segments into individual words, keep words > 1 char.
        // SFSpeechRecognizer sometimes produces segments containing
        // multiple words (e.g. "sedang melakukan fixing") — we need
        // to split them so each word is assessed individually.
        let refWordsCleaned: [String] = windowedSegments.flatMap { seg in
            seg.substring
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
                .split(separator: " ")
                .map { String($0) }
                .filter { $0.count > 1 }
        }
        guard !refWordsCleaned.isEmpty else { return [] }

        // ── Step 1: Build full text strings ─────────────────────────
        let refText = refWordsCleaned.joined(separator: " ")
        let acousticText = acoustic.words.map { $0.text }.joined(separator: " ")

        // Compute char ranges for each reference word in refText
        var refWordRanges: [(word: String, range: Range<Int>)] = []
        var cursor = 0
        for word in refWordsCleaned {
            let start = cursor
            cursor += word.count
            refWordRanges.append((word: word, range: start..<cursor))
            cursor += 1 // space separator
        }

        // Compute char ranges for each acoustic word in acousticText
        var acWordRanges: [(range: Range<Int>, word: AcousticWord)] = []
        cursor = 0
        for word in acoustic.words {
            let start = cursor
            cursor += word.text.count
            acWordRanges.append((range: start..<cursor, word: word))
            cursor += 1 // space separator
        }

        // ── Step 2: Character-level LCS alignment ───────────────────
        // Lowercase both strings for fair comparison (EN model outputs
        // uppercase, ID model outputs lowercase).
        let blocks = SequenceMatcher.matchingBlocks(
            reference: refText.lowercased(),
            hypothesis: acousticText.lowercased()
        )

        // Build reverse mapping: acoustic char → reference char
        var acCharToRefChar: [Int: Int] = [:]
        for block in blocks {
            for offset in 0..<block.size {
                let refIdx = block.referenceRange.lowerBound + offset
                let acIdx = block.hypothesisRange.lowerBound + offset
                acCharToRefChar[acIdx] = refIdx
            }
        }

        // ── Step 3: For each acoustic word, find covered ref words ──
        //
        // An acoustic word "covers" a reference word if any of its
        // characters are LCS-mapped to any character of the reference
        // word. This handles CTC word merging: "halnam" covers both
        // "halo" and "nama" because its chars map to chars in both
        // reference words.

        struct AcousticAssessment {
            let acousticWord: AcousticWord
            let coveredRefWordIndices: [Int]
            let combinedRefText: String
            let similarity: Float
        }

        var acousticAssessments: [AcousticAssessment] = []

        for (acRange, acWord) in acWordRanges {
            // Find which ref word indices this acoustic word covers
            var coveredRefIdxs = Set<Int>()
            for acCharIdx in acRange {
                if let refCharIdx = acCharToRefChar[acCharIdx] {
                    for (refWordIdx, (_, refRange)) in refWordRanges.enumerated() {
                        if refRange.contains(refCharIdx) {
                            coveredRefIdxs.insert(refWordIdx)
                        }
                    }
                }
            }
            if coveredRefIdxs.isEmpty { continue }

            let sortedRefIdxs = coveredRefIdxs.sorted()
            // Combine covered reference words (no spaces) for comparison
            let combinedRef = sortedRefIdxs.map { refWordRanges[$0].word }.joined()
            let sim = EditDistance.similarity(normalize(combinedRef), normalize(acWord.text))

            acousticAssessments.append(AcousticAssessment(
                acousticWord: acWord,
                coveredRefWordIndices: sortedRefIdxs,
                combinedRefText: combinedRef,
                similarity: sim
            ))
        }

        // ── Step 4: For each reference word, find best assessment ────
        //
        // A reference word may be covered by multiple acoustic words
        // (e.g. "kemampuan" heard as "ke" + "membuan"). We take the
        // acoustic word with the highest similarity as the best
        // representative for that reference word.

        var assessments: [WordAssessment] = []
        for (refWordIdx, (refWord, _)) in refWordRanges.enumerated() {
            let covering = acousticAssessments.filter {
                $0.coveredRefWordIndices.contains(refWordIdx)
            }

            if covering.isEmpty {
                // No acoustic word covers this ref word → missed entirely
                assessments.append(WordAssessment(
                    acousticWord: "—",
                    acousticConfidence: 0.0,
                    referenceWord: refWord,
                    referenceSubstring: "",
                    similarity: 0.0,
                    decision: .mispronounced
                ))
                continue
            }

            // Take the assessment with the best (highest) similarity
            let best = covering.max { $0.similarity < $1.similarity }!
            let decision = bandDecision(
                similarity: best.similarity,
                acousticConfidence: best.acousticWord.confidence
            )

            assessments.append(WordAssessment(
                acousticWord: best.acousticWord.text,
                acousticConfidence: best.acousticWord.confidence,
                referenceWord: refWord,
                referenceSubstring: best.combinedRefText,
                similarity: best.similarity,
                decision: decision
            ))
        }

        // ── Debug output ────────────────────────────────────────────
        let mispronouncedCount = assessments.filter { $0.decision == .mispronounced }.count
        print("🔗 alignment[\(languageCode)]: \(assessments.count) ref words (\(refWordRanges.count) in window), \(mispronouncedCount) mispronounced")
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
}
