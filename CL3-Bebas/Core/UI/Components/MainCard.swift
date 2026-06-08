//
//  MainCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 06/06/26.
//

import SwiftUI

struct MainCard: View {
    private enum Dimension {
        static let width: CGFloat = 359
        static let height: CGFloat = 195
        static let headerHeight: CGFloat = 86
        static let scoreWidth: CGFloat = 108
    }
    
    let color: Color
    let icon: String
    let aspect: String
    let score: String?
    let title: String
    let gaugeValue: Double
    let gaugeRange: ClosedRange<Double>
    let goodRange: ClosedRange<Double>
    let slowLabel: String
    let rangeLabel: String
    let fastLabel: String
    
    init(
        color: Color = .RedPrimarySC,
        icon: String = AppIcon.pace,
        aspect: String = "Pace",
        score: String? = nil,
        title: String = "Too Fast",
        gaugeValue: Double = 188,
        gaugeRange: ClosedRange<Double> = 60...220,
        goodRange: ClosedRange<Double> = 130...160,
        slowLabel: String = "Too Slow",
        rangeLabel: String = "Good Range",
        fastLabel: String = "Too Fast"
    ) {
        self.color = color
        self.icon = icon
        self.aspect = aspect
        self.score = score
        self.title = title
        self.gaugeValue = gaugeValue
        self.gaugeRange = gaugeRange
        self.goodRange = goodRange
        self.slowLabel = slowLabel
        self.rangeLabel = rangeLabel
        self.fastLabel = fastLabel
    }
    
    init(
        color: String,
        icon: String = AppIcon.pace,
        aspect: String = "Pace",
        score: String? = nil,
        title: String = "Too Fast",
        gaugeValue: Double = 188,
        gaugeRange: ClosedRange<Double> = 60...220,
        goodRange: ClosedRange<Double> = 130...160,
        slowLabel: String = "Too Slow",
        rangeLabel: String = "Good Range",
        fastLabel: String = "Too Fast"
    ) {
        self.init(
            color: Color(color),
            icon: icon,
            aspect: aspect,
            score: score,
            title: title,
            gaugeValue: gaugeValue,
            gaugeRange: gaugeRange,
            goodRange: goodRange,
            slowLabel: slowLabel,
            rangeLabel: rangeLabel,
            fastLabel: fastLabel
        )
    }
    
    private var displayedScore: String {
        score ?? "\(formatted(gaugeValue)) WPM"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Dimension.headerHeight)
                .background(color)
            
            LinearGauge(
                value: gaugeValue,
                range: gaugeRange,
                goodRange: goodRange,
                accentColor: color,
                slowLabel: slowLabel,
                rangeLabel: rangeLabel,
                fastLabel: fastLabel
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.whiteSC)
        }
        .frame(width: Dimension.width, height: Dimension.height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
    
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(.whiteSC.opacity(0.78))
                .frame(width: 40, height: 40)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(aspect)
                    .font(Text.CustomHeadline)
                    .foregroundColor(.whiteSC)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(title)
                    .font(Text.CustomLargeTitle)
                    .foregroundColor(.whiteSC)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.top, 8)
            .layoutPriority(1)
            
            Spacer(minLength: 0)
            
            Text(displayedScore)
                .font(Text.CustomBody)
                .foregroundColor(.whiteSC)
                .lineLimit(1)
                .frame(width: Dimension.scoreWidth, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: false)
                .padding(.top, 12)
                .padding(.trailing, 6)
        }
    }
    
    private func formatted(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0)))
    }
}

struct LinearGauge: View {
    let value: Double
    let range: ClosedRange<Double>
    let goodRange: ClosedRange<Double>
    let accentColor: Color
    let slowLabel: String
    let rangeLabel: String
    let fastLabel: String
    
    private var clampedValue: Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
    
    private var valuePosition: CGFloat {
        let total = range.upperBound - range.lowerBound
        
        guard total > 0 else { return 0 }
        return CGFloat((clampedValue - range.lowerBound) / total)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(slowLabel)
                Spacer()
                Text(rangeLabel)
                Spacer()
                Text(fastLabel)
            }
            .font(Text.CustomHeadline)
            .foregroundColor(.black)
            
            VStack(spacing: 6) {
                Gauge(value: clampedValue, in: range) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(accentColor)
                
                labels
            }
        }
    }
    
    private var labels: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                gaugeLabel(formatted(range.lowerBound), color: .GreyAccentSC, isActive: false)
                    .position(x: boundedPosition(for: range.lowerBound, in: proxy.size.width), y: 14)
                
                gaugeLabel(formatted(goodRange.lowerBound), color: .GreyAccentSC, isActive: false)
                    .position(x: boundedPosition(for: goodRange.lowerBound, in: proxy.size.width), y: 14)
                
                gaugeLabel(formatted(goodRange.upperBound), color: .GreyAccentSC, isActive: false)
                    .position(x: boundedPosition(for: goodRange.upperBound, in: proxy.size.width), y: 14)
                
                gaugeLabel(formatted(range.upperBound), color: .GreyAccentSC, isActive: false)
                    .position(x: boundedPosition(for: range.upperBound, in: proxy.size.width), y: 14)
                
                gaugeLabel(formatted(clampedValue), color: accentColor, isActive: true)
                    .position(x: boundedCurrentValuePosition(in: proxy.size.width), y: 14)
            }
        }
        .frame(height: 28)
    }
    
    private func gaugeLabel(
        _ text: String,
        color: Color,
        isActive: Bool
    ) -> some View {
        Text(text)
            .font(isActive ? Text.CustomHeadline : Text.CustomBody)
            .foregroundColor(color)
            .frame(width: 44)
    }
    
    private func boundedPosition(for number: Double, in width: CGFloat) -> CGFloat {
        let total = range.upperBound - range.lowerBound
        let labelHalfWidth: CGFloat = 22
        
        guard total > 0 else { return labelHalfWidth }
        
        let position = CGFloat((number - range.lowerBound) / total) * width
        return min(max(position, labelHalfWidth), width - labelHalfWidth)
    }
    
    private func boundedCurrentValuePosition(in width: CGFloat) -> CGFloat {
        let labelHalfWidth: CGFloat = 22
        let position = valuePosition * width
        
        return min(max(position, labelHalfWidth), width - labelHalfWidth)
    }

    private func formatted(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0)))
    }
}

struct MainCard_Previews: PreviewProvider {
    static var previews: some View {
        MainCard(
            color: .RedPrimarySC,
            icon: AppIcon.pace,
            aspect: "Pace",
            score: "180 WPM",
            title: "Too Fast",
            gaugeValue: 180,
            gaugeRange: 60...220,
            goodRange: 130...160,
            slowLabel: "Too Slow",
            rangeLabel: "Good Range",
            fastLabel: "Too Fast"
        )
            .padding(20)
            .previewLayout(.sizeThatFits)
    }
}
