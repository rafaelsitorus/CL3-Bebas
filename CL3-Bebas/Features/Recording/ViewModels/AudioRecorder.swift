//
//  AudioRecorder.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//

import Foundation
import AVFoundation // microphone access, audio engine, file writing
import Accelerate // quick computation
import Combine // published reactive state
import Speech // apple on device speech recognition

// MARK: - Audio Sample Data

struct AudioSampleData {
    var amplitudeSamples: [Float] = []      // RMS loudness amplitude over time
    var pitchSamples: [Float] = []          // F0 frequency estimates over time
    var recordingDuration: TimeInterval = 0
    var audioFileURL: URL? // saved .m4a file

}

// MARK: - AudioRecorder

@MainActor
class AudioRecorder: NSObject, ObservableObject {

    // MARK: Published State
    @Published var isRecording = false
    @Published var currentAmplitude: Float = 0.0   // live RMS for waveform UI
    @Published var currentPitch: Float = 0.0        // live F0 for UI
    @Published var recordingTime: TimeInterval = 0

    // MARK: Private
    var speechRequest: SFSpeechAudioBufferRecognitionRequest?   // ← add
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private let audioFileLock = NSLock()
    private var displayLink: Timer?
    private var startTime: Date?

    // Lets pauseRecording()/resumeRecording() exclude the paused
    // interval from both the live `recordingTime` and the final
    // duration handed back from `stopRecording()`.
    private var pausedDuration: TimeInterval = 0
    private var pauseStartedAt: Date?

    private var amplitudeSamples: [Float] = []
    private var pitchSamples: [Float] = []
    private var audioFileURL: URL?

    // FFT
    private let fftSize = 4096
    private var fftSetup: FFTSetup?
    private var window: [Float] = []
    private var sampleRate: Float = 44100
   

    override init() {
        super.init()
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
    }

    // MARK: - Public API

    func startRecording() {
        guard !isRecording else { return } // prevent double start
        requestMicPermission { [weak self] granted in
            guard granted, let self else { return }
            Task { @MainActor in
                self.beginRecording()// hop to main thread before touching AVAudio
            
            }
        }
    }

    /// Pauses the underlying AVAudioEngine — the mic genuinely stops
    /// capturing (no audio, no waveform/level updates) rather than
    /// just hiding it in the UI while still recording.
    func pauseRecording() {
        guard isRecording, pauseStartedAt == nil else { return }
        audioEngine.pause()
        displayLink?.invalidate()
        displayLink = nil
        pauseStartedAt = Date()
    }

    /// Resumes a paused recording in place — same engine, same taps,
    /// same output file.
    func resumeRecording() {
        guard isRecording, let pausedAt = pauseStartedAt else { return }
        do {
            try audioEngine.start()
        } catch {
            print("AudioRecorder resume error: \(error)")
            return
        }
        pausedDuration += Date().timeIntervalSince(pausedAt)
        pauseStartedAt = nil
        startDisplayLink()
    }

    func stopRecording() -> AudioSampleData {
        isRecording = false
        speechRequest?.endAudio()  // ← add this
        speechRequest = nil
        displayLink?.invalidate()
        displayLink = nil
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        // Give the audio engine time to flush remaining buffers
        // before closing the file
        Thread.sleep(forTimeInterval: 0.3)
        
        audioFileLock.lock()
        audioFile = nil
        audioFileLock.unlock()
        
        // Exclude any paused time — including a pause that's still
        // active right when stop is called — from the reported duration.
        let pausedNow = pausedDuration + (pauseStartedAt.map { Date().timeIntervalSince($0) } ?? 0)
        let duration = startTime.map { Date().timeIntervalSince($0) - pausedNow } ?? 0
        pauseStartedAt = nil
        
        let nonZero = pitchSamples.filter { $0 > 0 }.count
        print("🎵 pitch samples: \(pitchSamples.count) total, \(nonZero) voiced")

        return AudioSampleData(
            amplitudeSamples: amplitudeSamples,
            pitchSamples: pitchSamples,
            recordingDuration: duration,
            audioFileURL: audioFileURL
        )
    }
    func reset() {
        amplitudeSamples = []
        pitchSamples = []
        audioFileURL = nil
        currentAmplitude = 0
        currentPitch = 0
        recordingTime = 0
        startTime = nil
        pausedDuration = 0
        pauseStartedAt = nil
    }

    // MARK: - Private
    
   

    private func requestMicPermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        @unknown default:
            completion(false)
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)

            audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            sampleRate = Float(inputFormat.sampleRate)

            // Setup audio file
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("pitch_recording_\(Date().timeIntervalSince1970).caf")
            audioFileURL = url

            // Use LPCM format for file writing
            _ = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 1,
                interleaved: false
            )!

            let cafSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true
            ]
            let newFile = try AVAudioFile(forWriting: url, settings: cafSettings)
            audioFileLock.lock()
            audioFile = newFile
            audioFileLock.unlock()
            
       
           

            // Tap the input with ~50ms chunks
            let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.05)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
                // Capture startTime on audio thread — safe because startTime is set
                // before installTap and never changed while recording
                let elapsed = self.map { recorder -> TimeInterval in
                    guard let start = recorder.startTime else { return 0 }
                    return Date().timeIntervalSince(start)
                } ?? 0
                self?.processBuffer(buffer, elapsedSeconds: elapsed)
            }
            
            


            amplitudeSamples = []
            pitchSamples = []
            startTime = Date()
            pausedDuration = 0
            pauseStartedAt = nil
            
            try audioEngine.start()
            isRecording = true
            startDisplayLink()

        } catch {
            print("AudioRecorder error: \(error)")
        }
    }

    /// Shared by beginRecording() and resumeRecording() so the 0.1s
    /// recordingTime ticker isn't duplicated.
    private func startDisplayLink() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.startTime else { return }
                self.recordingTime = Date().timeIntervalSince(start) - self.pausedDuration
            }
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, elapsedSeconds: TimeInterval) {
        speechRequest?.append(buffer)

        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let chCount = Int(buffer.format.channelCount)

        var monoSamples = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            var sum: Float = 0
            for ch in 0..<chCount { sum += channelData[ch][i] }
            monoSamples[i] = sum / Float(chCount)
        }

        // Capture file reference under lock
        audioFileLock.lock()
        let capturedFile = audioFile
        audioFileLock.unlock()

        if let capturedFile,
           let writeFormat = AVAudioFormat(
               commonFormat: .pcmFormatFloat32,
               sampleRate: buffer.format.sampleRate,
               channels: 1,
               interleaved: false),
           let writeBuf = AVAudioPCMBuffer(pcmFormat: writeFormat,
                                           frameCapacity: AVAudioFrameCount(frameCount)) {
            writeBuf.frameLength = AVAudioFrameCount(frameCount)
            if let dst = writeBuf.floatChannelData {
                dst[0].update(from: monoSamples, count: frameCount)
            }
            do {
                try capturedFile.write(from: writeBuf)
            } catch {
                print("❌ write error: \(error)")
            }
        } else {
            print("❌ capturedFile is nil — audioFile not set yet")
        }

        // RMS + pitch
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameCount))
        let db = 20 * log10(max(rms, 1e-9))
        let f0 = estimateF0(samples: channelData[0], count: frameCount, sampleRate: sampleRate)

        DispatchQueue.main.async { [weak self, rms, db, f0] in
            guard let self else { return }
            self.currentAmplitude = rms
            self.currentPitch = f0
            self.amplitudeSamples.append(db)
            self.pitchSamples.append(f0)
        }
    }
    // MARK: - Pitch F0 Estimation (Autocorrelation)

    private func estimateF0(samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        guard count >= 512 else { return 0 }
        let n = min(count, 2048)
        var buf = [Float](UnsafeBufferPointer(start: samples, count: n))

        // Check if signal is loud enough
        var rms: Float = 0
        vDSP_rmsqv(&buf, 1, &rms, vDSP_Length(n))
        guard rms > 0.001 else { return 0 } // silence : no pitch

        // Autocorrelation with signal itself
        var acf = [Float](repeating: 0, count: n)
        vDSP_conv(&buf, 1, &buf, 1, &acf, 1, vDSP_Length(n), vDSP_Length(n))

        // Search for first peak in human speech F0 range (80–400 Hz)
        let minLag = Int(sampleRate / 400) // 400Hz → lag = 110 samples
        let maxLag = Int(sampleRate / 80) // 80Hz  → lag = 551 samples
        guard maxLag < n else { return 0 }

        var peakVal: Float = -Float.infinity
        
        // Step 4: Confidence check
        var peakLag = minLag
        for lag in minLag..<min(maxLag, acf.count) {
            if acf[lag] > peakVal {
                peakVal = acf[lag]
                peakLag = lag
            }
        }

        // Confidence check vs zero-lag
        guard acf[0] > 0, peakVal / acf[0] > 0.3 else { return 0 }
        // weak peak = noise, not voice
        // convert lag → frequency
        return sampleRate / Float(peakLag)
    }
}
