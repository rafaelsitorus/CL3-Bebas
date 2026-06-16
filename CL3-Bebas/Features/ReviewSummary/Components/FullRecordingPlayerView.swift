//
//  FullRecordingPlayerView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import SwiftUI

// MARK: - FullRecordingPlayerView
struct FullRecordingPlayerView: View {

    // MARK: Properties

    @ObservedObject var player: FullRecordingPlayer
    let result: AnalysisResult

    // MARK: Body

    var body: some View {
        AudioPlaybackCard(
            isPlaying: player.isPlaying,
            currentTime: player.currentTime,
            duration: result.duration
        ) {
            player.togglePlayback()
        }
    }
}
