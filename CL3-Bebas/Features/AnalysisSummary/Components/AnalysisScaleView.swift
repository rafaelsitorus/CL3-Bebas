import SwiftUI

// MARK: - Tick

struct ScaleTick {
    let fraction: Double   // 0–1 position on the track
    let label: String
    let isBold: Bool       // true = the "current value" tick
}

// MARK: - AnalysisScaleView

struct AnalysisScaleView: View {

    let fraction: Double        // dot position 0–1
    let ticks: [ScaleTick]      // all tick labels to show above the track
    let leadingLabel: String
    let trailingLabel: String

    // Highlighted range on the track (e.g. "normal" zone) — optional
    var highlightRange: ClosedRange<Double>? = nil

    private var clampedFraction: CGFloat {
        CGFloat(max(0, min(1, fraction)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tickLabels
            track
            endpointLabels
        }
    }

    // MARK: Tick labels row

    // MARK: Tick labels row

    private var tickLabels: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                    TickLabel(tick: tick, trackWidth: geo.size.width)
                }
            }
        }
        .frame(height: 16)
    }
    // MARK: Track

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 4)

                // Optional highlight zone (e.g. normal/ideal range)
                if let range = highlightRange {
                    let x = geo.size.width * CGFloat(range.lowerBound)
                    let w = geo.size.width * CGFloat(range.upperBound - range.lowerBound)
                    Capsule()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: w, height: 4)
                        .offset(x: x)
                }

                // Filled portion up to dot
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: geo.size.width * clampedFraction, height: 4)

                // Dot
                Circle()
                    .fill(Color.black)
                    .frame(width: 14, height: 14)
                    .offset(x: geo.size.width * clampedFraction - 7)
            }
            .frame(height: 14, alignment: .center)
        }
        .frame(height: 14)
    }

    // MARK: Endpoint labels

    private var endpointLabels: some View {
        HStack {
            Text(leadingLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(trailingLabel)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.black)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - TickLabel

/// Reads its own width via PreferenceKey so it can pin:
///   fraction == 0  → leading edge flush with track start
///   fraction == 1  → trailing edge flush with track end
///   else           → centered on fraction
private struct TickLabel: View {
    let tick: ScaleTick
    let trackWidth: CGFloat

    @State private var labelWidth: CGFloat = 0

    var body: some View {
        Text(tick.label)
            .font(.caption)
            .fontWeight(tick.isBold ? .bold : .regular)
            .foregroundStyle(tick.isBold ? Color.black : Color.secondary)
            .fixedSize()
            .background(
                GeometryReader { g in
                    Color.clear.onAppear { labelWidth = g.size.width }
                }
            )
            .offset(x: xOffset)
            .frame(height: 16, alignment: .top)
    }

    private var xOffset: CGFloat {
        let center = trackWidth * CGFloat(tick.fraction) - labelWidth / 2
        if tick.fraction <= 0.01 {
            return 0                          // flush left
        } else if tick.fraction >= 0.99 {
            return trackWidth - labelWidth    // flush right
        } else {
            return center
        }
    }
}
