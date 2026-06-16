//
//  PhonemeModelLoader.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//

//  Loads Wav2Vec2Phoneme.mlpackage (converted via convert_wav2vec2_phoneme.py)
//  and phoneme_vocab.json (bundled resources), runs inference on raw 16kHz
//  mono audio, and CTC-decodes the output into a phoneme sequence.
//
//  Confirmed model spec (Xcode preview):
//    input_values : Float32 (1 x N), N in 1600...480000
//    logits       : Float32 (1, T, vocab_size) — vocab_size = 392
//


import Foundation
import CoreML
import Accelerate

// MARK: - Vocab loading

struct PhonemeVocab: Decodable {
    let id2phoneme: [String: String]
    let pad_id: Int
    let vocab_size: Int
    let sample_rate: Int
    let do_normalize: Bool

    static func load(from bundle: Bundle = .main, filename: String = "phoneme_vocab") -> PhonemeVocab? {
        guard let url = bundle.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PhonemeVocab.self, from: data)
    }

    func phonemeTable() -> [String] {
        var table = [String](repeating: "", count: vocab_size)
        for (k, v) in id2phoneme {
            if let idx = Int(k), idx < vocab_size { table[idx] = v }
        }
        return table
    }
}

// MARK: - PhonemeModelRunner

final class PhonemeModelRunner {

    // Model is loaded asynchronously; nil until ready.
    private var model: MLModel?
    private let vocab: PhonemeVocab?
    private let phonemeTable: [String]
    private let ignoredTokens: Set<String> = ["<pad>", "<s>", "</s>", "<unk>", "|"]

    /// Synchronous init — only loads vocab (fast, just JSON).
    /// Call `loadModelAsync()` immediately after to start the heavy work
    /// on a background thread.
    init(modelName: String = "Wav2Vec2Phoneme") {
        self.vocab = PhonemeVocab.load()
        self.phonemeTable = vocab?.phonemeTable() ?? []
        self._modelName = modelName
        print("🧠 Vocab loaded: \(vocab != nil), table size: \(phonemeTable.count)")
    }

    private let _modelName: String

    /// Fire-and-forget background model load.
    /// Safe to call from any thread/actor.
    func loadModelAsync() {
        let name = _modelName
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlpackage")
            ?? Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            print("🧠 ❌ model not found in bundle")
            return
        }
        
        print("🧠 Loading model on background thread: \(url)")
        
        // Use plain DispatchQueue instead of Swift concurrency —
        // MLModel can deadlock inside Task.detached on iOS 26 beta
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly
                print("🧠 Calling MLModel(contentsOf:)...")
                let loaded = try MLModel(contentsOf: url, configuration: config)
                print("🧠 ✅ Model loaded successfully")
                DispatchQueue.main.async {
                    self.model = loaded
                }
            } catch {
                print("🧠 ❌ Load failed: \(error)")
            }
        }
    }

    var isReady: Bool { model != nil && vocab != nil }

    func extractPhonemes(samples: [Float]) -> [String] {
        guard let model, let vocab, !samples.isEmpty else { return [] }

        let minSamples = 1600
        let maxSamples = 480_000
        var clipped = samples
        if clipped.count > maxSamples { clipped = Array(clipped.prefix(maxSamples)) }
        else if clipped.count < minSamples {
            clipped.append(contentsOf: [Float](repeating: 0, count: minSamples - clipped.count))
        }

        let normalized = vocab.do_normalize ? zScoreNormalize(clipped) : clipped

        guard let inputArray = try? MLMultiArray(shape: [1, NSNumber(value: normalized.count)], dataType: .float32) else {
            return []
        }
        normalized.withUnsafeBufferPointer { src in
            let dst = inputArray.dataPointer.bindMemory(to: Float32.self, capacity: normalized.count)
            dst.update(from: src.baseAddress!, count: normalized.count)
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: ["input_values": inputArray]),
              let result = try? model.prediction(from: provider),
              let logits = result.featureValue(for: "logits")?.multiArrayValue else {
            return []
        }
        return ctcDecode(logits: logits)
    }

    private func zScoreNormalize(_ samples: [Float]) -> [Float] {
        var mean: Float = 0
        var std: Float = 0
        vDSP_normalize(samples, 1, nil, 1, &mean, &std, vDSP_Length(samples.count))
        var result = [Float](repeating: 0, count: samples.count)
        var negMean = -mean
        var invStd: Float = std > 1e-8 ? 1.0 / std : 1.0
        vDSP_vsadd(samples, 1, &negMean, &result, 1, vDSP_Length(samples.count))
        vDSP_vsmul(result, 1, &invStd, &result, 1, vDSP_Length(samples.count))
        return result
    }

    private func ctcDecode(logits: MLMultiArray) -> [String] {
        let shape = logits.shape.map { $0.intValue }
        guard shape.count == 3 else { return [] }
        let timeSteps = shape[1]
        let vocabSize = shape[2]

        let ptr = logits.dataPointer.bindMemory(to: Float32.self, capacity: timeSteps * vocabSize)
        var tokenIds: [Int] = []
        tokenIds.reserveCapacity(timeSteps)

        for t in 0..<timeSteps {
            var best: Float = -Float.infinity
            var bestIdx = 0
            let base = t * vocabSize
            for v in 0..<vocabSize {
                let val = ptr[base + v]
                if val > best { best = val; bestIdx = v }
            }
            tokenIds.append(bestIdx)
        }

        var phonemes: [String] = []
        var previous: Int? = nil
        let padId = vocab?.pad_id ?? 0

        for id in tokenIds {
            if id == previous { continue }
            previous = id
            if id == padId { continue }
            guard id < phonemeTable.count else { continue }
            let token = phonemeTable[id]
            if ignoredTokens.contains(token) || token.isEmpty { continue }
            phonemes.append(token)
        }
        return phonemes
    }
}
