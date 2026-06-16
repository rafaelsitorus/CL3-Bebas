//
//  AnalysisScaleView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//


import SwiftUI

// MARK: - AnalysisScaleView

/// A reusable horizontal score scale used across all three analysis
/// detail screens (Articulation, Intonation, Pace).
///
/// Layout (matches mockup):
///   ```
///   0%    25%    43%    100%
///   ━━━━━━━━━━●──────────
///   Leading              Trailing
///   ```
///
/// Parameters
/// - `fraction`: Position of the marker dot, clamped 0…1.
/// - `tickLabel`: The centre tick label (e.g. "43%" or "±35 Hz").
/// - `leadingLabel`: Left endpoint label  (e.g. "Clear" / "Expressive" / "Ideal").
/// - `trailingLabel`: Right endpoint label (e.g. "Unclear" / "Flat" / "Too Fast").

struct AnalysisScaleView: View {

    // MARK: Properties

    /// 0–1 position of the dot on the track.
    let fraction: Double
    /// Label shown at the midpoint tick — usually the formatted score.
    let tickLabel: String
    /// Left endpoint label.
    let leadingLabel: String
    /// Right endpoint label.
    let trailingLabel: String

    // MARK: Private

    private var clampedFraction: CGFloat {
        CGFloat(fraction.clamped(to: 0...1))
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tickLabels
            track
            endpointLabels
        }
    }

    // MARK: Sub-views

    private var tickLabels: some View {
        HStack {
            Text("0%")
            Spacer()
            Text("25%")
            Spacer()
            Text(tickLabel)
                .fontWeight(.bold)
                .foregroundStyle(.black)
            Spacer()
            Text("100%")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 4)

                // Filled portion
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: geo.size.width * clampedFraction, height: 4)

                // Marker dot
                Circle()
                    .fill(Color.black)
                    .frame(width: 14, height: 14)
                    .offset(x: geo.size.width * clampedFraction - 7)
            }
            .frame(height: 14, alignment: .center)
        }
        .frame(height: 14)
    }

    private var endpointLabels: some View {
        HStack {
            Text(leadingLabel)
            Spacer()
            Text(trailingLabel)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Double clamped (file-private)

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        AnalysisScaleView(
            fraction: 0.43,
            tickLabel: "43%",
            leadingLabel: "Clear",
            trailingLabel: "Unclear"
        )
        AnalysisScaleView(
            fraction: 0.7,
            tickLabel: "±56 Hz",
            leadingLabel: "Expressive",
            trailingLabel: "Flat"
        )
        AnalysisScaleView(
            fraction: 1.0,
            tickLabel: "100%",
            leadingLabel: "Ideal",
            trailingLabel: "Too Fast"
        )
    }
    .padding(24)
}
