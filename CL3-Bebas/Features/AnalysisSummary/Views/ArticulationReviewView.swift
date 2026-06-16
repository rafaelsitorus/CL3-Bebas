//
//  ArticulationReviewView.swift
//  CL3-Bebas

import SwiftUI

struct ArticulationReviewView: View {

    // MARK: Properties

    let result: AnalysisResult

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    private var scorePercent: Int {
        Int((result.articulationScore * 100).rounded())
    }

    private var scaleFraction: Double {
        Double(1 - result.articulationScore).clamped(to: 0...1)
    }
    
    private var inaccuracyPercent: Int { Int(((1 - result.articulationScore) * 100).rounded()) }
    private var inaccuracyFraction: Double { Double(1 - result.articulationScore) }


    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                backButton
                sectionLabel("ANALYSIS")
                headerRow
                AnalysisScaleView(
                    fraction: inaccuracyFraction,
                    ticks: [
                        ScaleTick(fraction: 0.0,  label: "0%",  isBold: false),
                        ScaleTick(fraction: 0.25, label: "25%", isBold: false),
                        ScaleTick(fraction: inaccuracyFraction,
                                  label: "\(inaccuracyPercent)%",
                                  isBold: true),
                        ScaleTick(fraction: 1.0,  label: "100%", isBold: false),
                    ],
                    leadingLabel: "Clear",
                    trailingLabel: "Unclear",
                    highlightRange: 0.25...1.0   // above 25% = unclear zone
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
        .navigationBarHidden(true)
    }

    // MARK: Sub-views

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.06)))
        }
        .padding(.top, 8)
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
                    .foregroundStyle(.black)
                Text("INACCURACY")
                    .font(Text.CustomExpandedSH)
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
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(result.pronunciationIssues.isEmpty)
            .opacity(result.pronunciationIssues.isEmpty ? 0.4 : 1)
        }
    }

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("HOW TO IMPROVE")
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

    // MARK: Copy

    private var explanation: String {
        let unclearCount = result.pronunciationIssues.count
        let totalWords = result.transcription.split(separator: " ").count
        let unclearPercent = totalWords > 0
            ? Int((Float(unclearCount) / Float(totalWords)) * 100)
            : 0

        switch result.articulationScore {
        case 0.90...:
            return "Excellent clarity — almost every word came through crisply."
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
            "Emphasize vowel sounds more clearly.",
            "Pronounce each syllable deliberately.",
        ]
        let droppedEndings = result.pronunciationIssues.contains {
            $0.suggestion.localizedCaseInsensitiveContains("dropping") ||
            $0.suggestion.localizedCaseInsensitiveContains("ending")
        }
        if droppedEndings || result.pronunciationIssues.isEmpty {
            tips.append("Pay attention to word endings and consonants.")
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
