//
//  ArticulationPipelineSpeech.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//

import Foundation
import Speech

enum ArticulationPipelineSpeech {

    static func run(
        segments: [SFTranscriptionSegment],
        recordingDuration: TimeInterval,
        languageCode: String = "en"
    ) -> (score: Float, issues: [PronunciationIssue]) {
        guard !segments.isEmpty else { return (0.5, []) }

        let wordSegments = segments.filter {
            let clean = $0.substring
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
            return clean.count > 1
        }

        guard !wordSegments.isEmpty else { return (0.5, []) }

        let confidences = wordSegments.map { Float($0.confidence) }
        let mean = confidences.reduce(0, +) / Float(confidences.count)
        let variance = confidences.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(confidences.count)
        let stdDev = sqrt(variance)

        // ── Zero-confidence bail-out ─────────────────────────────────
        // Indonesian SFSpeech returns confidence=0 for every segment.
        // mean=0 + sd=0 forces threshold=0.15 → every word is flagged
        // unclear → score 0.00 with a wall of bogus issues. The legacy
        // pipeline has no signal in this case; return a neutral score
        // and empty issues rather than punish the speaker for ASR
        // returning a structurally useless number.
        if mean < 0.01 {
            print("🗣️ [\(languageCode)] mean=\(String(format:"%.2f",mean)) sd=\(String(format:"%.2f",stdDev)) — SFSpeech returned no usable confidence, returning neutral score")
            return (0.5, [])
        }

        // ── Language-aware absolute floor ─────────────────────────────
        // Indonesian ASR returns structurally lower confidence (~0.3–0.5)
        // even for correctly spoken words. English is typically 0.6–0.9.
        // The relative threshold (mean - N*SD) catches genuine outliers;
        // the absolute floor prevents flagging everything on low-confidence languages.
        let absoluteFloor: Float = languageCode == "en" ? 0.35 : 0.15

        // Use 1.5 SD instead of 1.0 SD — only flag real outliers, not
        // the bottom quarter of a normally-distributed session.
        let relativeThreshold = mean - (1.5 * stdDev)
        let threshold = max(relativeThreshold, absoluteFloor)

        print("🗣️ [\(languageCode)] mean=\(String(format:"%.2f",mean)) sd=\(String(format:"%.2f",stdDev)) threshold=\(String(format:"%.2f",threshold))")
        print("🗣️ Scores: \(wordSegments.map { "\($0.substring)=\(String(format:"%.2f",$0.confidence))" }.joined(separator:", "))")

        let totalWords = wordSegments.count
        let unclearSegments = wordSegments.filter { Float($0.confidence) < threshold }
        let clearCount = totalWords - unclearSegments.count
        let overallScore = Float(clearCount) / Float(totalWords)

        print("🗣️ \(clearCount)/\(totalWords) clear → score \(String(format:"%.2f", overallScore))")

        // ── Build issues list ─────────────────────────────────────────
        var issues: [PronunciationIssue] = []
        for (idx, seg) in segments.enumerated() {
            let clean = seg.substring
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
            guard clean.count > 1, Float(seg.confidence) < threshold else { continue }

            let windowStart = max(0, idx - 5)
            let windowEnd   = min(segments.count - 1, idx + 5)
            let window      = Array(segments[windowStart...windowEnd])
            let sentenceText     = window.map { $0.substring }.joined(separator: " ")
            let sentenceStart    = TimeInterval(window.first?.timestamp ?? seg.timestamp)
            let lastSeg          = window.last!
            let sentenceEnd      = TimeInterval(lastSeg.timestamp) + TimeInterval(lastSeg.duration)
            let sentenceDuration = max(1.0, sentenceEnd - sentenceStart)

            issues.append(PronunciationIssue(
                word: clean,
                timestamp: TimeInterval(seg.timestamp),
                confidence: Float(seg.confidence),
                suggestion: suggestion(for: clean, confidence: Float(seg.confidence), languageCode: languageCode),
                sentences: [PronunciationExampleSentence(
                    text: sentenceText,
                    highlightedWord: clean,
                    audioFileURL: nil,
                    startTime: sentenceStart,
                    duration: sentenceDuration
                )]
            ))
        }

        var seen = Set<String>()
        let deduped = issues
            .sorted { $0.confidence < $1.confidence }
            .filter { seen.insert($0.word.lowercased()).inserted }

        print("🗣️ \(deduped.count) unclear words: \(deduped.map { $0.word })")
        return (overallScore, deduped)
    }

    // ── Suggestion copy ───────────────────────────────────────────────
    // Now receives languageCode so we can tailor the message if needed.
    private static func suggestion(for word: String, confidence: Float, languageCode: String = "en") -> String {
        switch confidence {
        case ..<0.2:
            return "'\(word)' was very hard to recognise. Slow down and open your mouth more on each syllable."
        case 0.2..<0.35:
            return "'\(word)' was unclear. Focus on consonants at the start and end of the word."
        default:
            return "'\(word)' could be slightly clearer. Emphasise the stressed syllable."
        }
    }

    // MARK: - Dual-path pipeline (acoustic + reference)

    /// Score + issues derived from the CHARACTER-LEVEL ALIGNMENT between
    /// the Wav2Vec2 acoustic transcript and the SFSpeechRecognizer
    /// reference transcript. Used when the Wav2Vec2 model is loaded
    /// successfully (the preferred path).
    ///
    /// Behaviour:
    /// - Each `WordAssessment` whose `decision == .mispronounced` becomes
    ///   a `PronunciationIssue` whose `word` is the REFERENCE form
    ///   (the one the recognizer agreed on), but whose `acousticWord`
    ///   holds the raw form the user actually said.
    /// - `.unknownName` assessments are excluded from the issues list
    ///   (they represent OOV words, not articulation problems) but they
    ///   DO count in the score denominator — otherwise a transcript
    ///   where the acoustic model simply failed to detect half the
    ///   words would score a perfect 1.00 (10 matches / 10 scorable,
    ///   28 unknown silently dropped).
    /// - `.match` assessments are not surfaced.
    /// - Score uses weighted counts: match = 1.0, unknownName = 0.5,
    ///   mispronounced = 0.0. The half-credit for unknownName keeps
    ///   the score from collapsing when the acoustic model produces
    ///   borderline-but-not-confident output, while mispronounced
    ///   words still pull the score down hard (the user is the one
    ///   who actually mispronounced them). Returns 0.0 when no words
    ///   are assessed.
    static func runDualPath(
        segments: [SFTranscriptionSegment],
        assessments: [WordAssessment],
        recordingDuration: TimeInterval,
        languageCode: String = "en"
    ) -> (score: Float, issues: [PronunciationIssue]) {
        guard !assessments.isEmpty else { return (0.0, []) }

        // ── Score calculation ───────────────────────────────────────
        // Denominator = ALL assessed words (including unknownName).
        // Numerator   = weighted sum across decisions:
        //                 match       → 1.0 (clean hit)
        //                 unknownName → 0.5 (acoustic model produced
        //                                something but couldn't
        //                                classify it cleanly — the
        //                                user probably said it
        //                                fine, the model just isn't
        //                                sure; partial credit)
        //                 mispronounced → 0.0 (real articulation
        //                                problem, full penalty)
        //
        // The unknownName half-credit stops the score from collapsing
        // on borderline acoustic output (which would otherwise drag
        // a 0.80 run down to 0.47 just because the model couldn't
        // decide on a few words), while still leaving mispronounced
        // words with full negative impact.
        let totalAssessed = assessments.count
        let matchedCount = assessments.filter { $0.decision == .match }.count
        let unknownCount = assessments.filter { $0.decision == .unknownName }.count
        let weightedNumerator = Float(matchedCount) + Float(unknownCount) * 0.5
        let scorableCount = totalAssessed

        let mispronounced = assessments.filter { $0.decision == .mispronounced }

        // ── Build issues list ───────────────────────────────────────
        var issues: [PronunciationIssue] = []
        for assessment in mispronounced {
            let refWordLower = (assessment.referenceWord ?? assessment.referenceSubstring).lowercased()

            let segmentIdx: Int? = segments.firstIndex { seg in
                let clean = seg.substring
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespaces)
                return clean.lowercased() == refWordLower
            }

            let windowStart: Int = segmentIdx.map { max(0, $0 - 5) } ?? 0
            let windowEnd: Int = segmentIdx.map { min(segments.count - 1, $0 + 5) }
                ?? max(0, segments.count - 1)
            let window = (windowStart <= windowEnd) ? Array(segments[windowStart...windowEnd]) : []
            let sentenceText = window.map { $0.substring }.joined(separator: " ")
            let sentenceStart = TimeInterval(window.first?.timestamp ?? 0)
            let lastSeg = window.last
            let sentenceEnd = TimeInterval(lastSeg?.timestamp ?? 0) + TimeInterval(lastSeg?.duration ?? 0)
            let sentenceDuration = max(1.0, sentenceEnd - sentenceStart)

            let displayWord: String = {
                if let ref = assessment.referenceWord, !ref.isEmpty { return ref }
                if !assessment.referenceSubstring.isEmpty { return assessment.referenceSubstring }
                return assessment.acousticWord
            }()

            let simPercent = Int((assessment.similarity * 100).rounded())
            let suggestionText: String = {
                if assessment.acousticConfidence < ArticulationAlignment.acousticConfidenceFloor {
                    return "'\(displayWord)' was mumbled — confidence only \(Int(assessment.acousticConfidence * 100))%. Slow down and articulate each syllable."
                }
                return "'\(displayWord)' may have been mispronounced (matched at \(simPercent)%). The acoustic model heard '\(assessment.acousticWord)'. Listen back and try again."
            }()

            issues.append(PronunciationIssue(
                word: displayWord,
                timestamp: TimeInterval(segments[segmentIdx ?? 0].timestamp),
                confidence: assessment.acousticConfidence,
                suggestion: suggestionText,
                sentences: [PronunciationExampleSentence(
                    text: sentenceText,
                    highlightedWord: displayWord,
                    audioFileURL: nil,
                    startTime: sentenceStart,
                    duration: sentenceDuration
                )],
                acousticWord: assessment.acousticWord,
                referenceWord: assessment.referenceWord,
                isMispronounced: true,
                isUnknownName: false,
                renderedSentence: sentenceText
            ))
        }

        // Dedup by lowercased reference word, keep the worst-confidence
        // instance (lowest confidence = most clearly mispronounced).
        var seen = Set<String>()
        let deduped = issues
            .sorted { $0.confidence < $1.confidence }
            .filter { seen.insert($0.word.lowercased()).inserted }

        // Score: matched / total assessed (unknownName now counts
        // toward the denominator). If there are no assessed words,
        // return 0.0 — we have no evidence of clarity.
        let score: Float = scorableCount > 0
            ? weightedNumerator / Float(scorableCount)
            : 0.0

        print("🗣️ [\(languageCode)] dual-path: \(matchedCount)/\(scorableCount) matched + \(unknownCount) unknown (0.5wt) + \(assessments.count - matchedCount - unknownCount) mispronounced → score \(String(format: "%.2f", score))")
        print("🗣️ flagged: \(deduped.map { $0.word })")
        return (score, deduped)
    }
}
