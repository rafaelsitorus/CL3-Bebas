//
//  RecordingHeaderCard.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//


import SwiftUI

struct RecordingHeaderCard: View {
    let title: String
    let duration: String
    let date: String
    let audioLevels: [CGFloat]
    var isPlaying: Bool = false
    let onPlayTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Blue header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Text.CustomLargeTitle)
                        .foregroundColor(.whiteSC)
                        .lineLimit(1)
                    HStack {
                        Text(duration)
                            .font(Text.CustomBody)
                            .foregroundColor(.whiteSC.opacity(0.8))
                        Spacer()
                        Text(date)
                            .font(Text.CustomBody)
                            .foregroundColor(.whiteSC.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.BluePrimaryBC)

            // Waveform player
            HStack(spacing: 12) {
                Button(action: onPlayTap) {
                    ZStack {
                        Circle()
                            .fill(Color.whiteSC)
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        Image(systemName: isPlaying ? AppIcon.pauseIcon : AppIcon.playIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.BluePrimaryBC)
                    }
                }

                // Static waveform visualizer
                HStack(alignment: .center, spacing: 2) {
                    ForEach(audioLevels.indices, id: \.self) { i in
                        Capsule()
                            .fill(Color.GreyAccentSC.opacity(0.5))
                            .frame(width: 2.5, height: max(4, audioLevels[i] * 50))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.whiteSC)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
