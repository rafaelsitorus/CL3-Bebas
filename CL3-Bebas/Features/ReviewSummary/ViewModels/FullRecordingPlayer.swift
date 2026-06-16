//
//  FullRecordingPlayer.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import AVFoundation
import Combine
import SwiftUI

// MARK: - FullRecordingPlayer

@MainActor
final class FullRecordingPlayer: NSObject, ObservableObject {

    // MARK: Published state

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0

    // MARK: Internal state

    private(set) var totalDuration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    // MARK: Public API

    func load(url: URL, duration: TimeInterval) {
        totalDuration = duration
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
        } catch {
            print("FullRecordingPlayer load error: \(error)")
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        timer = nil
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        let t = fraction * totalDuration
        player.currentTime = max(0, min(t, totalDuration))
        currentTime = player.currentTime
    }

    // MARK: Private helpers

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension FullRecordingPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.currentTime = self.totalDuration
            self.timer?.invalidate()
            self.timer = nil
        }
    }
}
