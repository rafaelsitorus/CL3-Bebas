//
//  SegmentAudioPlayer.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//


//  Tiny ObservableObject wrapper around AVAudioPlayer for playing a single
//  recording (optionally seeking to a sub-segment) with a live progress
//  value for the scrubber UI in UnclearWordsView.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class SegmentAudioPlayer: NSObject, ObservableObject {

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    /// The segment this player is scoped to, in seconds within the file.
    private var segmentStart: TimeInterval = 0
    private var segmentDuration: TimeInterval = 0

    var duration: TimeInterval { segmentDuration }

    func load(url: URL, start: TimeInterval, duration: TimeInterval) {
        stop()
        segmentStart = start
        segmentDuration = duration
        currentTime = 0

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.currentTime = start
            player?.prepareToPlay()
        } catch {
            print("SegmentAudioPlayer: failed to load — \(error)")
            player = nil
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            pause()
        } else {
            // If we've played past the segment end, restart from segmentStart
            if player.currentTime >= segmentStart + segmentDuration || player.currentTime < segmentStart {
                player.currentTime = segmentStart
            }
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                let elapsed = player.currentTime - self.segmentStart
                self.currentTime = max(0, min(elapsed, self.segmentDuration))

                if player.currentTime >= self.segmentStart + self.segmentDuration {
                    self.pause()
                    self.currentTime = self.segmentDuration
                }
            }
        }
    }
}

extension SegmentAudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.pause()
        }
    }
}
