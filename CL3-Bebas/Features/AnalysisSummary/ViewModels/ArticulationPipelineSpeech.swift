//
//  ArticulationPipelineSpeech.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//


//  Alternative articulation pipeline using Speech framework confidence scores
//  instead of the Wav2Vec2 phoneme model. Swap in SpeechAnalyzer.swift by
//  changing the call site to use ArticulationPipelineSpeech.run() instead of
//  ArticulationPipeline.run().
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

        // Flag words more than 1 SD below session mean, with absolute floor
        let threshold = max(mean - stdDev, 0.3)

        print("🗣️ Confidence mean=\(String(format:"%.2f",mean)) sd=\(String(format:"%.2f",stdDev)) threshold=\(String(format:"%.2f",threshold))")
        print("🗣️ Scores: \(wordSegments.map { "\($0.substring)=\(String(format:"%.2f",$0.confidence))" }.joined(separator:", "))")

        let totalWords = wordSegments.count
        let unclearSegments = wordSegments.filter { Float($0.confidence) < threshold }
        let clearCount = totalWords - unclearSegments.count
        let overallScore = Float(clearCount) / Float(totalWords)

        print("🗣️ \(clearCount)/\(totalWords) clear → score \(overallScore)")

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
                suggestion: suggestion(for: clean, confidence: Float(seg.confidence)),
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
    private static func suggestion(for word: String, confidence: Float) -> String {
        switch confidence {
        case ..<0.3:
            return "'\(word)' was very hard to recognise. Slow down and open your mouth more on each syllable."
        case 0.3..<0.5:
            return "'\(word)' was unclear. Focus on consonants at the start and end of the word."
        default:
            return "'\(word)' could be slightly clearer. Emphasise the stressed syllable."
        }
    }
}

