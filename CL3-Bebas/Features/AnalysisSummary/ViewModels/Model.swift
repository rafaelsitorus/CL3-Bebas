//
//  Model.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//


import Foundation

struct WordTiming {
    var word: String
    var start: TimeInterval
    var end: TimeInterval
    var probability: Float
}

/// A sentence/segment in which a flagged word appeared, with its own audio
/// clip for playback (e.g. "I saw my mom **cooking** eleven ball of meats
/// for the whole family").
struct PronunciationExampleSentence: Identifiable {
    var id = UUID()
    var text: String            // full sentence text
    var highlightedWord: String // the word to bold within `text`
    var audioFileURL: URL?      // clip covering just this sentence, if available
    var startTime: TimeInterval // playback start offset into the full recording
    var duration: TimeInterval  // length of this segment
}

struct PronunciationIssue {
    var word: String
    var timestamp: TimeInterval
    var confidence: Float
    var suggestion: String

    /// Example sentences where this word was flagged.
    var sentences: [PronunciationExampleSentence] = []
}

/// A highlighted window of the recording for the "Audio Highlight" playback
/// shown on the Intonation / Pace detail screens — e.g. the most expressive
/// 10–20s segment for Intonation, or the section closest to ideal pace.
struct AudioHighlightSegment {
    var startTime: TimeInterval
    var duration: TimeInterval
}


extension PronunciationExampleSentence: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension PronunciationIssue: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.word == rhs.word && lhs.timestamp == rhs.timestamp
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
        hasher.combine(timestamp)
    }
}

extension AudioHighlightSegment: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.startTime == rhs.startTime && lhs.duration == rhs.duration
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(startTime)
        hasher.combine(duration)
    }
}
