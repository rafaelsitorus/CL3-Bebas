//
//  AudioHighlightCard.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//


import SwiftUI

// MARK: - AudioHighlightCard

struct AudioHighlightCard: View {

    // MARK: Properties

    let highlight: AudioHighlightSegment
    let audioFileURL: URL

    @StateObject private var player = SegmentAudioPlayer()

    // MARK: Body

    var body: some View {
        AudioPlaybackCard(
            isPlaying: player.isPlaying,
            currentTime: max(0, player.currentTime - highlight.startTime),
            duration: highlight.duration
        ) {
            // Lazy-load on the first play tap.
            if player.duration == 0 {
                player.load(
                    url: audioFileURL,
                    start: highlight.startTime,
                    duration: highlight.duration
                )
            }
            player.togglePlayback()
        }
        .onDisappear {
            player.stop()
        }
    }
}
