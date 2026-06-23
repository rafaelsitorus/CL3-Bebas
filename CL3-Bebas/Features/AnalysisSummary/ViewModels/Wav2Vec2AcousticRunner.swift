//
//  Wav2Vec2AcousticRunner.swift
//  CL3-Bebas
//
//  Acoustic-path CTC runner for the dual-path articulation pipeline.
//
//  Loads `Wav2Vec2_<LANG>.mlpackage` (character-level CTC), feeds it
//  5 seconds of 16 kHz mono audio, and CTC-decodes the resulting
//  logits into a sequence of words with per-word confidence.
//
//  Implementation follows the reference
//  `tes-model-akustik/ArticulationApp/{Wav2Vec2Service, CtcDecoder}.swift`
//  — same vocab format (`{ "0": "<pad>", ... }`), same Float16
//  input, same greedy argmax + collapse + group-to-words logic, and
//  same blank-token detection by name. Differences:
//    * batched / vectorised softmax (the reference is per-frame Python
//      style; we use vDSP-friendly loops on the Float32 logits once
//      they've been read out of the Float16 MLMultiArray).
//    * Background loading on a global queue (matches
//      `PhonemeModelRunner.loadModelAsync()`).
//

import Foundation
import CoreML
import Accelerate

// `AcousticWord` and `AcousticTranscript` are declared in
// `Model.swift` so they're shared cleanly with `ArticulationAlignment`.

// MARK: - Runner

final class Wav2Vec2AcousticRunner {

    /// Model expects 5 s @ 16 kHz = 80 000 samples per chunk.
    /// Confirmed from `load_spec` on the `.mlmodel` file.
    static let expectedSampleCount = 80_000

    /// Maximum audio duration we support (5 minutes @ 16 kHz).
    static let maxSamples = 16_000 * 300  // 4_800_000

    private var model: MLModel?
    private var vocabTable: [Int: String] = [:]   // token_id -> character
    private var blankTokenId: Int = 0
    private let _modelName: String
    private let _vocabResource: String

    /// Synchronous init — only loads vocab (fast, just JSON).
    /// Call `loadModelAsync()` immediately after to start the heavy
    /// MLModel load on a background thread.
    init(modelName: String, vocabResource: String) {
        self._modelName = modelName
        self._vocabResource = vocabResource
        loadVocab()
    }

    // MARK: - Vocab

    /// Parse the vocab JSON. We accept both shapes the reference
    /// decoder accepts:
    ///   * `{ "0": "<pad>", "1": "<s>", ... }`  (object form)
    ///   * `["<pad>", "<s>", ...]`              (array form)
    private func loadVocab() {
        guard let url = Bundle.main.url(forResource: _vocabResource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("🧠 ❌ vocab file not found: \(_vocabResource).json")
            return
        }
        var raw: [String: String] = [:]
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            raw = dict
        } else if let arr = try? JSONDecoder().decode([String].self, from: data) {
            for (i, v) in arr.enumerated() { raw[String(i)] = v }
        } else {
            print("🧠 ❌ vocab file has unknown format")
            return
        }
        var table: [Int: String] = [:]
        for (k, v) in raw { if let i = Int(k) { table[i] = v } }
        self.vocabTable = table

        // Detect the CTC blank token by name (matches reference).
        let padCandidates = ["<pad>", "[PAD]", "<blank>", "[BLANK]", "<ctc>", "[CTC]"]
        let blank = padCandidates.compactMap { name -> Int? in
            table.first(where: { $0.value == name })?.key
        }.first ?? 0
        self.blankTokenId = blank

        print("🧠 Wav2Vec2 vocab[\(_vocabResource)]: table size=\(table.count), blank=\(blank)")
    }

    // MARK: - Async MLModel load

    /// Fire-and-forget background model load. Safe to call from any
    /// thread/actor.
    func loadModelAsync() {
        let name = _modelName
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: name, withExtension: "mlpackage") else {
            print("🧠 ❌ Wav2Vec2 model '\(name)' not found in bundle")
            return
        }

        print("🧠 Loading Wav2Vec2 model on background thread: \(url)")

        // Plain DispatchQueue instead of Swift concurrency — MLModel can
        // deadlock inside Task.detached on iOS 26 beta (same reason as
        // PhonemeModelLoader.swift).
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let config = MLModelConfiguration()
                // CPU-only keeps startup time low. The reference uses
                // .cpuAndGPU but it also takes <2s; the simpler choice
                // here is fine for our 5-second inputs.
                config.computeUnits = .cpuOnly
                let loaded = try MLModel(contentsOf: url, configuration: config)
                print("🧠 ✅ Wav2Vec2 model loaded")
                DispatchQueue.main.async {
                    self.model = loaded
                }
            } catch {
                print("🧠 ❌ Wav2Vec2 load failed: \(error)")
            }
        }
    }

    var isReady: Bool { model != nil && !vocabTable.isEmpty }

    /// Run CTC decode on raw audio. Caller is expected to have
    /// resampled to 16 kHz mono float32 first (see
    /// `SpeechAnalyzer.resampleTo16kStatic`). The model internally
    /// converts to Float16.
    ///
    /// Supports up to 5 minutes of audio by chunking into 5-second
    /// windows and concatenating the CTC-decoded output.
    func transcribe(samples: [Float]) -> AcousticTranscript {
        guard let model, !vocabTable.isEmpty else {
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }
        guard !samples.isEmpty else {
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }

        // Clamp to max supported duration (5 minutes).
        let clamped = samples.count > Self.maxSamples
            ? Array(samples.prefix(Self.maxSamples))
            : samples

        // Split into 5-second chunks.
        let chunkSize = Self.expectedSampleCount
        let chunkCount = (clamped.count + chunkSize - 1) / chunkSize

        var allWords: [AcousticWord] = []
        var totalFrames = 0

        for chunkIdx in 0..<chunkCount {
            let start = chunkIdx * chunkSize
            let end = min(start + chunkSize, clamped.count)
            let chunk = Array(clamped[start..<end])

            // Pad the last chunk if it's shorter than 5 seconds.
            let prepared = Self.prepareSamples(chunk, targetLength: chunkSize)

            guard let inputArray = makeFloat16MultiArray(prepared) else {
                print("🧠 ❌ failed to build input MultiArray for chunk \(chunkIdx)")
                continue
            }

            let result: MLFeatureProvider
            do {
                let provider = try MLDictionaryFeatureProvider(dictionary: ["audio": inputArray])
                result = try model.prediction(from: provider)
            } catch {
                print("🧠 ❌ Wav2Vec2 prediction failed for chunk \(chunkIdx): \(error)")
                continue
            }

            guard let logits = result.featureValue(for: "logits")?.multiArrayValue else {
                print("🧠 ❌ 'logits' feature missing from chunk \(chunkIdx) output")
                continue
            }

            let chunkTranscript = ctcDecode(logits: logits)

            // Offset frame indices by the cumulative frame count so
            // they're globally consistent.
            for word in chunkTranscript.words {
                allWords.append(AcousticWord(
                    text: word.text,
                    confidence: word.confidence,
                    frameStart: word.frameStart + totalFrames,
                    frameEnd: word.frameEnd + totalFrames
                ))
            }
            totalFrames += chunkTranscript.framesProcessed
        }

        // ── Collapse chunk-boundary duplicates ───────────────────────
        // Wav2Vec2 chunked inference can re-emit the same word at the
        // seam between adjacent 5-second chunks when audio bleeds
        // across the boundary. Two consecutive words with the same
        // text and overlapping frame ranges are the same utterance
        // heard twice; keep the higher-confidence one and drop the
        // rest. We deliberately don't do global dedup — a user might
        // genuinely repeat a word later in the recording.
        let deduped = Wav2Vec2AcousticRunner.collapseChunkBoundaryDuplicates(allWords)
        if deduped.droppedCount > 0 {
            print("🧠 collapsed \(deduped.droppedCount) chunk-boundary duplicate acoustic words")
        }

        print("🧠 acoustic transcript (\(chunkCount) chunks): \(deduped.words.map { "'\($0.text)'(\(String(format: "%.2f", $0.confidence)))" })")
        return AcousticTranscript(
            words: deduped.words,
            framesProcessed: totalFrames,
            sampleRate: 16_000
        )
    }

    /// Wav2Vec2 time-step stride is ~20 ms, so 5 frames ≈ 100 ms of
    /// audio. Two words with the same text and frame ranges within
    /// that window are almost certainly a chunk-boundary repeat.
    private static func collapseChunkBoundaryDuplicates(
        _ words: [AcousticWord]
    ) -> (words: [AcousticWord], droppedCount: Int) {
        guard words.count > 1 else { return (words, 0) }

        var result: [AcousticWord] = [words[0]]
        var dropped = 0
        for i in 1..<words.count {
            let prev = result[result.count - 1]
            let cur = words[i]
            let isSameText = prev.text.lowercased() == cur.text.lowercased()
            // Frames overlap if cur's start is within ~100ms of prev's end.
            let isOverlapping = cur.frameStart <= prev.frameEnd + 5
            if isSameText && isOverlapping {
                // Keep the higher-confidence copy.
                if cur.confidence > prev.confidence {
                    result[result.count - 1] = cur
                }
                dropped += 1
            } else {
                result.append(cur)
            }
        }
        return (result, dropped)
    }

    // MARK: - Audio prep

    private static func prepareSamples(_ samples: [Float], targetLength: Int) -> [Float] {
        if samples.count == targetLength { return samples }
        if samples.count > targetLength { return Array(samples.prefix(targetLength)) }
        return samples + Array(repeating: 0, count: targetLength - samples.count)
    }

    /// Build a Float16 MLMultiArray of shape [1, N] from Float32
    /// samples. Mirrors `Wav2Vec2Service.floatArrayToMLMultiArray`.
    private func makeFloat16MultiArray(_ samples: [Float]) -> MLMultiArray? {
        let shape = [1, samples.count] as [NSNumber]
        guard let array = try? MLMultiArray(shape: shape, dataType: .float16) else {
            return nil
        }
        let halfBuffer = samples.map { Float16($0) }
        halfBuffer.withUnsafeBufferPointer { buffer in
            guard let baseAddr = buffer.baseAddress else { return }
            let destPtr = array.dataPointer.bindMemory(to: Float16.self, capacity: halfBuffer.count)
            destPtr.initialize(from: baseAddr, count: halfBuffer.count)
        }
        return array
    }

    // MARK: - CTC decode

    /// Greedy CTC decode: argmax → collapse consecutive duplicates →
    /// drop blank → group into words at the word-boundary token.
    ///
    /// Faithful to `CtcDecoder.decode(logits:)` in the reference repo.
    func ctcDecode(logits: MLMultiArray) -> AcousticTranscript {
        let shape = logits.shape.map { $0.intValue }
        guard shape.count == 3 else {
            print("🧠 ❌ unexpected logits shape: \(shape)")
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }
        let timeSteps = shape[1]
        let vocabSize = shape[2]
        guard timeSteps > 0, vocabSize > 0 else {
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }

        // Per-frame: argmax over vocab, plus softmax probability of the
        // argmax as the per-frame confidence. The reference computes
        // softmax via a per-frame O(V) loop; we do the same for
        // clarity. A 249×28 sweep is < 7k ops — negligible.
        var tokens: [(tokenId: Int, confidence: Float)] = []
        tokens.reserveCapacity(timeSteps)
        for t in 0..<timeSteps {
            var frame = [Float](repeating: 0, count: vocabSize)
            for v in 0..<vocabSize {
                let idx = [0, t, v] as [NSNumber]
                frame[v] = logits[idx].floatValue
            }
            // Softmax + argmax. Use a numerically-stable variant
            // (subtract max before exp).
            var maxVal: Float = -.greatestFiniteMagnitude
            for v in 0..<vocabSize where frame[v] > maxVal { maxVal = frame[v] }
            var sumExp: Float = 0
            var expVals = [Float](repeating: 0, count: vocabSize)
            for v in 0..<vocabSize {
                let e = expf(frame[v] - maxVal)
                expVals[v] = e
                sumExp += e
            }
            if sumExp > 0 {
                let inv = 1.0 / sumExp
                for v in 0..<vocabSize { expVals[v] *= inv }
            }
            var bestIdx = 0
            var bestVal: Float = -.greatestFiniteMagnitude
            for v in 0..<vocabSize where expVals[v] > bestVal {
                bestVal = expVals[v]
                bestIdx = v
            }
            tokens.append((bestIdx, bestVal))
        }

        // Step 2: collapse consecutive duplicate tokens + drop blank.
        // Keep the original CTC time-step alongside each kept token so
        // we can later report it as the word's frame range — that
        // range is what the alignment layer uses to map acoustic words
        // onto the recording timeline.
        var collapsed: [(tokenId: Int, confidence: Float, timeStep: Int)] = []
        var prevTokenId: Int? = nil
        for (t, (tokenId, confidence)) in tokens.enumerated() {
            if tokenId == blankTokenId {
                prevTokenId = nil  // blank resets the "same as prev" state
                continue
            }
            if tokenId == prevTokenId { continue }
            collapsed.append((tokenId: tokenId, confidence: confidence, timeStep: t))
            prevTokenId = tokenId
        }

        // Step 3: group characters into words.
        let specialTokens: Set<String> = [
            "<pad>", "[PAD]", "<s>", "</s>", "<unk>", "[UNK]",
            "<blank>", "[BLANK]", "<ctc>", "[CTC]"
        ]
        let wordSeparator = vocabTable.first(where: { $0.value == "|" })?.key
            ?? vocabTable.first(where: { $0.value == " " })?.key
            ?? -1

        var words: [AcousticWord] = []
        var currentChars: [String] = []
        var currentConfs: [Float] = []
        var currentStartFrame = 0
        var lastFrame = 0

        func flush(endFrame: Int) {
            guard !currentChars.isEmpty else { return }
            let joined = currentChars.joined()
                .replacingOccurrences(of: "|", with: "")
            let trimmed = joined.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let avg = currentConfs.reduce(0, +) / Float(currentConfs.count)
            words.append(AcousticWord(
                text: trimmed,
                confidence: avg,
                frameStart: currentStartFrame,
                frameEnd: endFrame
            ))
            currentChars = []
            currentConfs = []
        }

        for (_, (tokenId, conf, timeStep)) in collapsed.enumerated() {
            // Use the ORIGINAL CTC time-step (carried through the
            // collapse step) as the word's frame index — not the
            // collapsed position. The collapsed index would compress
            // every word into the first second of audio; the real
            // time-step lets the alignment layer spread acoustic
            // words across the full recording timeline.
            lastFrame = timeStep
            let char = vocabTable[tokenId] ?? ""
            if specialTokens.contains(char) { continue }

            if tokenId == wordSeparator || char == " " {
                flush(endFrame: timeStep)
                currentStartFrame = timeStep + 1
            } else {
                if currentChars.isEmpty { currentStartFrame = timeStep }
                currentChars.append(char)
                currentConfs.append(conf)
            }
        }
        flush(endFrame: lastFrame)

        print("🧠 acoustic transcript: \(words.map { "'\($0.text)'(\(String(format: "%.2f", $0.confidence)))" })")
        return AcousticTranscript(
            words: words,
            framesProcessed: timeSteps,
            sampleRate: 16_000
        )
    }
}
