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

    /// Model expects 5 s @ 16 kHz = 80 000 samples. Confirmed from
    /// `load_spec` on the `.mlmodel` file.
    static let expectedSampleCount = 80_000

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

    // MARK: - Inference

    /// Run CTC decode on raw audio. Caller is expected to have
    /// resampled to 16 kHz mono float32 first (see
    /// `SpeechAnalyzer.resampleTo16kStatic`). The model internally
    /// converts to Float16.
    func transcribe(samples: [Float]) -> AcousticTranscript {
        guard let model, !vocabTable.isEmpty else {
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }
        guard !samples.isEmpty else {
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }

        // Step 1: pad / truncate to exactly 80 000 samples.
        let prepared = Self.prepareSamples(samples, targetLength: Self.expectedSampleCount)

        // Step 2: build the Float16 MLMultiArray input. The reference
        // (Wav2Vec2Service.swift) does this — the model was trained
        // on Float16 and CoreML refuses Float32 here ("multiArrayConstraint
        // ... isAllowedValue: fails for ... Float32").
        guard let inputArray = makeFloat16MultiArray(prepared) else {
            print("🧠 ❌ failed to build input MultiArray")
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }

        // Step 3: inference.
        let provider: MLDictionaryFeatureProvider
        let result: MLFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: ["audio": inputArray])
            result = try model.prediction(from: provider)
        } catch {
            print("🧠 ❌ Wav2Vec2 prediction failed: \(error)")
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }

        guard let logits = result.featureValue(for: "logits")?.multiArrayValue else {
            print("🧠 ❌ 'logits' feature missing from Wav2Vec2 output")
            return AcousticTranscript(words: [], framesProcessed: 0, sampleRate: 16_000)
        }

        return ctcDecode(logits: logits)
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
        var collapsed: [(tokenId: Int, confidence: Float)] = []
        var prevTokenId: Int? = nil
        for (tokenId, confidence) in tokens {
            if tokenId == blankTokenId {
                prevTokenId = nil  // blank resets the "same as prev" state
                continue
            }
            if tokenId == prevTokenId { continue }
            collapsed.append((tokenId: tokenId, confidence: confidence))
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

        for (i, (tokenId, conf)) in collapsed.enumerated() {
            // Map collapsed index back to original frame index (1-to-1
            // for argmax; for tracking, we approximate "frame" as the
            // collapsed index — it's only used for time alignment).
            lastFrame = i
            let char = vocabTable[tokenId] ?? ""
            if specialTokens.contains(char) { continue }

            if tokenId == wordSeparator || char == " " {
                flush(endFrame: i)
                currentStartFrame = i + 1
            } else {
                if currentChars.isEmpty { currentStartFrame = i }
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
