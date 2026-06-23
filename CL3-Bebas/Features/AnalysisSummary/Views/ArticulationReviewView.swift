//
//  ArticulationReviewView.swift
//  CL3-Bebas

import SwiftUI

struct ArticulationReviewView: View {

    // MARK: Properties

    let result: AnalysisResult

    // MARK: Private

    private var scorePercent: Int {
        Int((result.articulationScore * 100).rounded())
    }

    private var inaccuracyPercent: Int { Int(((1 - result.articulationScore) * 100).rounded()) }

    /// Maps inaccuracy to 0–50% scale for the bar display.
    /// The bar represents 0% to 50% inaccuracy; values above 50%
    /// pin to the right edge.
    private var scaleFraction: Double {
        Double(min(inaccuracyPercent, 50)) / 50.0
    }


    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sectionLabel("ANALYSIS")
                headerRow
                AnalysisScaleView(
                    fraction: scaleFraction,
                    ticks: scaleTicks,
                    leadingLabel: "Clear",
                    trailingLabel: "Unclear",
                    highlightRange: 0.0...0.50,              // green = 0%–25% inaccuracy on 0–50 scale
                    highlightColor: Color.BarGreenAnalysis,
                    dotColor: articulationColor,
                    activeEndpoint: inaccuracyPercent > 25 ? .trailing : .leading
                )
                explanationText
                Divider()
                wordHighlightSection
                Divider()
                improvementSection
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(white: 0.96).ignoresSafeArea())
        .navigationTitle("Articulation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.black)
        .toolbar(.hidden, for: .bottomBar)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Articulation")
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(.black)
                Text("Clarity of Word")
                    .font(Text.CustomBody)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(inaccuracyPercent)%")
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(inaccuracyPercent > 25 ? Color.MainRedAnalysis : Color.MainGreenAnalysis)
                Text("INACCURACY")
                    .font(Text.CustomFootnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var explanationText: some View {
        Text(explanation)
            .font(Text.CustomBody)
            .foregroundStyle(.black.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var wordHighlightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("WORD HIGHLIGHT")
            Text("Review words that may have been difficult for your listeners to recognize.")
                .font(Text.CustomBody)
                .foregroundStyle(.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: AppRoute.unclearWords(result.pronunciationIssues, result.audioFileURL)) {
                HStack {
                    Text("See the unclear words")
                        .font(Text.CustomHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: AppIcon.chevronRightIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.PrimaryAppColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(result.pronunciationIssues.isEmpty)
            .opacity(result.pronunciationIssues.isEmpty ? 0.4 : 1)
        }
    }

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("PITCHING TIPS")
                .font(Text.CustomExpandedSH)
            ImprovementTipsList(tips: improvementTips)
        }
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
    }
    private var articulationColor: Color {
        inaccuracyPercent > 25 ? Color.MainRedAnalysis : Color.MainGreenAnalysis
    }

    /// Build scale ticks for the 0%–50% bar, avoiding overlapping labels.
    /// Always show 0%, 25%, and 50% ticks, plus the actual inaccuracy%
    /// tick if it doesn't collide with any of the fixed ticks.
    private var scaleTicks: [ScaleTick] {
        var ticks: [ScaleTick] = [
            ScaleTick(fraction: 0.0, label: "0%", isBold: false),
            ScaleTick(fraction: 0.50, label: "25%", isBold: false),
            ScaleTick(fraction: 1.0, label: "50%", isBold: false),
        ]
        // Add the actual inaccuracy tick if it doesn't overlap with fixed ticks.
        // "Overlap" is defined as being within 0.08 fraction units of a fixed tick.
        let actualFraction = scaleFraction
        let fixedFractions: [Double] = [0.0, 0.50, 1.0]
        let tooClose = fixedFractions.contains { abs($0 - actualFraction) < 0.08 }
        if !tooClose {
            ticks.append(ScaleTick(fraction: actualFraction,
                                   label: "\(inaccuracyPercent)%",
                                   isBold: true))
        }
        return ticks
    }

    // MARK: Copy

    private var explanation: String {
        let unclearCount = result.pronunciationIssues.count
        let totalWords = result.transcription.split(separator: " ").count
        let unclearPercent = totalWords > 0
            ? Int((Float(unclearCount) / Float(totalWords)) * 100)
            : 0

        switch result.articulationScore {
        case 0.90...:
            return "Excellent clarity, almost every word came through crisply."
        case 0.75...:
            return "Good articulation. \(unclearCount) word\(unclearCount == 1 ? "" : "s") could be sharper."
        case 0.50...:
            return "\(unclearPercent)% of your words were unclear, which may reduce the clarity of your pitch."
        default:
            return "More than half your words were difficult to recognise. Focus on slowing down and enunciating each syllable."
        }
    }

    private var improvementTips: [String] {
        var tips = [
            "Open your mouth clearly when speaking to improve word clarity.",
            "Pronounce each syllable deliberately.",
            "Slow down when saying difficult words.",
        ]
        let droppedEndings = result.pronunciationIssues.contains {
            $0.suggestion.localizedCaseInsensitiveContains("dropping") ||
            $0.suggestion.localizedCaseInsensitiveContains("ending")
        }
        if droppedEndings || result.pronunciationIssues.isEmpty {
            tips.append("Make sure the beginning and ending sounds of each word can be heard clearly, especially technical terms and key messages.")
        }
        return tips
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
    NavigationStack {
        ArticulationReviewView(
            result: AnalysisResult(
                transcription: "I saw my mom cooking eleven ball of meats for the whole family",
                duration: 20,
                wordsPerMinute: 120,
                paceLabel: "Normal",
                averageAmplitudeDB: -20,
                volumeLabel: "Good",
                pitchSamples: [],
                pitchVariance: 100,
                intonationLabel: "Flat",
                amplitudeSamples: [],
                articulationScore: 0.43,
                pronunciationIssues: [
                    PronunciationIssue(
                        word: "Cooking", timestamp: 3, confidence: 0.43,
                        suggestion: "The word was pronounced unclearly several times.",
                        sentences: [
                            PronunciationExampleSentence(
                                text: "I saw my mom cooking eleven ball of meats for the whole family",
                                highlightedWord: "cooking",
                                audioFileURL: nil,
                                startTime: 3,
                                duration: 20
                            )
                        ]
                    ),
                    PronunciationIssue(word: "Spinach", timestamp: 8, confidence: 0.5, suggestion: "Unclear."),
                    PronunciationIssue(word: "Recipe",  timestamp: 12, confidence: 0.6, suggestion: "Unclear.")
                ],
                audioFileURL: nil,
                intonationHighlight: nil,
                paceHighlight: nil
            )
        )
    }
}
