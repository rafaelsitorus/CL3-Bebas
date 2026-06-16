//
//  AudioPlaybackCard.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import SwiftUI

struct AudioPlaybackCard: View {

    // MARK: Properties

    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let playPauseAction: () -> Void

    // MARK: Body

    var body: some View {
        HStack(spacing: 12) {

            // Play / Pause button
            Button(action: playPauseAction) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black)
                    .clipShape(Circle())
            }

            // Progress bar + timestamps
            VStack(alignment: .leading, spacing: 6) {
                progressBar
                timeLabels
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 75)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.3), lineWidth: 0.3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Sub-views

    private var progressBar: some View {
        GeometryReader { geo in
            let fraction = duration > 0
                ? (currentTime / duration).clamped(to: 0...1)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: geo.size.width * fraction, height: 6)
            }
        }
        .frame(height: 6)
    }

    private var timeLabels: some View {
        HStack {
            Text(timeString(currentTime))
            Spacer()
            Text(timeString(duration))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: Helpers

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(max(0, t.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Double clamped helper (file-private)

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
