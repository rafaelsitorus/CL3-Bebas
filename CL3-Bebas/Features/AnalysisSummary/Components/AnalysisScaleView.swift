import SwiftUI

// MARK: - Tick

struct ScaleTick {
    let fraction: Double
    let label: String
    let isBold: Bool
}

// MARK: - AnalysisScaleView

struct AnalysisScaleView: View {

    let fraction: Double
    let ticks: [ScaleTick]
    let leadingLabel: String
    let trailingLabel: String

    var highlightRange: ClosedRange<Double>? = nil
    var highlightColor: Color = Color.BarGreenAnalysis
    var dotColor: Color = .black
    var activeEndpoint: ActiveEndpoint = .none

    enum ActiveEndpoint {
        case leading, trailing, none
    }

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

    private var tickLabels: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                    TickLabel(tick: tick, trackWidth: geo.size.width, boldColor: dotColor)
                }
            }
        }
        .frame(height: 16)
    }

    // MARK: Track

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {

                // Layer 1 — full grey bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.10))
                    .frame(width: geo.size.width, height: 8)

                // Layer 2 — green zone bar (static, always same position)
                if let range = highlightRange {
                    let x = geo.size.width * CGFloat(range.lowerBound)
                    let w = geo.size.width * CGFloat(range.upperBound - range.lowerBound)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(highlightColor)
                        .frame(width: w, height: 8)
                        .offset(x: x)
                }

                // Layer 3 — dot (moves with fraction)
                Circle()
                    .fill(dotColor)
                    .frame(width: 16, height: 16)
                    .offset(x: geo.size.width * clampedFraction - 8)
            }
            .frame(height: 16, alignment: .center)
        }
        .frame(height: 16)
    }

    // MARK: Endpoint labels

    private var endpointLabels: some View {
        HStack {
            Text(leadingLabel)
                .font(.caption)
                .fontWeight(activeEndpoint == .leading ? .bold : .regular)
                .foregroundStyle(activeEndpoint == .leading ? dotColor : Color.secondary)
            Spacer()
            Text(trailingLabel)
                .font(.caption)
                .fontWeight(activeEndpoint == .trailing ? .bold : .regular)
                .foregroundStyle(activeEndpoint == .trailing ? dotColor : Color.secondary)
        }
    }
}

// MARK: - TickLabel

private struct TickLabel: View {
    let tick: ScaleTick
    let trackWidth: CGFloat
    let boldColor: Color

    @State private var labelWidth: CGFloat = 0

    var body: some View {
        Text(tick.label)
            .font(.caption)
            .fontWeight(tick.isBold ? .bold : .regular)
            .foregroundStyle(tick.isBold ? boldColor : Color.secondary)
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
            return 0
        } else if tick.fraction >= 0.99 {
            return trackWidth - labelWidth
        } else {
            return center
        }
    }
}
