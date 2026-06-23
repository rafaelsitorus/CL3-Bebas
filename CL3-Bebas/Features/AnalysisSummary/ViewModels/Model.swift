//
//  Model.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//


import Foundation

struct WordTiming: Codable, Hashable {
    var word: String
    var start: TimeInterval
    var end: TimeInterval
    var probability: Float
}

/// A sentence/segment in which a flagged word appeared, with its own audio
/// clip for playback (e.g. "I saw my mom **cooking** eleven ball of meats
/// for the whole family").
struct PronunciationExampleSentence: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String            // full sentence text
    var highlightedWord: String // the word to bold within `text`
    var audioFileURL: URL?      // clip covering just this sentence, if available
    var startTime: TimeInterval // playback start offset into the full recording
    var duration: TimeInterval  // length of this segment
}

struct PronunciationIssue: Codable, Hashable {
    var word: String
    var timestamp: TimeInterval
    var confidence: Float
    var suggestion: String

    /// Example sentences where this word was flagged.
    var sentences: [PronunciationExampleSentence] = []

    // MARK: - Dual-path (acoustic vs. reference) fields
    //
    // Populated by `ArticulationPipelineSpeech.runDualPath(...)` when
    // the Wav2Vec2 acoustic path is available. Default values keep
    // older JSON (persisted in SwiftData) decodable without migration.

    /// What the acoustic model actually heard. For a mispronounced
    /// dictionary word this is the "wrong" form (e.g. "komuntoas");
    /// for an unknown name/loanword it is the only form we have.
    var acousticWord: String?

    /// The "rapi" form the reference (SFSpeechRecognizer) produced
    /// for this position (e.g. "komunitas"). When the two agree, this
    /// is identical to `word`.
    var referenceWord: String?

    /// `true` when similarity is in the 0.4 – 0.8 band — a
    /// mispronounced dictionary word that should be highlighted in red.
    var isMispronounced: Bool = false

    /// `true` when similarity is below 0.4 — the reference and the
    /// acoustic disagree so strongly that we treat the word as an
    /// out-of-vocabulary name/loanword and do NOT flag it. (These
    /// `PronunciationIssue` rows are not created in the first place
    /// when this is the case, but the flag is kept for future
    /// analysis that may want to surface them.)
    var isUnknownName: Bool = false

    /// Optional pre-rendered full sentence with the flagged word(s)
    /// already wrapped in `**…**` markers, so the view can do its own
    /// highlighting. The default `SentencePlaybackCard` already does
    /// case-insensitive bold using `highlightedWord`; this is for the
    /// NEW multi-word highlighting path.
    var renderedSentence: String?
}

/// A single word produced by the acoustic path (Wav2Vec2 CTC), with its
/// mean per-frame CTC confidence. Lives in `Model.swift` (not in
/// `Wav2Vec2AcousticRunner.swift`) so it is shared cleanly with the
/// alignment layer.
struct AcousticWord: Hashable {
    let text: String
    let confidence: Float
    /// Inclusive range of CTC time-steps that this word covers. Useful
    /// for time-aligning acoustic words with `SFTranscriptionSegment`
    /// timestamps later if we want to (currently unused but kept for
    /// future work).
    let frameStart: Int
    let frameEnd: Int
}

struct AcousticTranscript: Hashable {
    let words: [AcousticWord]
    let framesProcessed: Int
    let sampleRate: Int
}

/// A highlighted window of the recording for the "Audio Highlight" playback
/// shown on the Intonation / Pace detail screens — e.g. the most expressive
/// 10–20s segment for Intonation, or the section closest to ideal pace.
struct AudioHighlightSegment: Codable, Hashable {
    var startTime: TimeInterval
    var duration: TimeInterval
}


extension PronunciationExampleSentence {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension PronunciationIssue {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.word == rhs.word && lhs.timestamp == rhs.timestamp
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
        hasher.combine(timestamp)
    }
}

extension AudioHighlightSegment {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.startTime == rhs.startTime && lhs.duration == rhs.duration
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(startTime)
        hasher.combine(duration)
    }
}
