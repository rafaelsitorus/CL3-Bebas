//
//  IntonationReviewView.swift

import SwiftUI

struct IntonationReviewView: View {

    // MARK: Properties

    let result: AnalysisResult

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    // MARK: PDQ Calculation
    private var pdq: Double {
        let samples = result.pitchSamples.filter { $0 > 0 }
        guard samples.count >= 2 else { return 0 }
        let meanPitch = Double(samples.reduce(0, +)) / Double(samples.count)
        guard meanPitch > 0 else { return 0 }
        let sumAbsDiff = zip(samples, samples.dropFirst())
            .map { abs(Double($1) - Double($0)) }
            .reduce(0, +)
        let mad = sumAbsDiff / Double(samples.count - 1)
        return mad / meanPitch
    }

    private var pdqNormalized: Double {
        min(1.0, pdq / 0.16)
    }

   
    private var pdqDisplay: String {
        String(format: "%.2f", min(pdq, 0.99))   // cap display at 0.99 to avoid "1.00"
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sectionLabel("ANALYSIS")
                headerRow
                AnalysisScaleView(
                    fraction: pdqNormalized,
                    ticks: [
                        ScaleTick(fraction: 0.0,
                                  label: "0",
                                  isBold: false),
                        ScaleTick(fraction: 0.625,
                                  label: "0.6",
                                  isBold: false),   // normalized 0.625 = raw 0.10/0.16
                        ScaleTick(fraction: min(1.0, pdqNormalized),
                                  label: pdqDisplay,
                                  isBold: true),
                        ScaleTick(fraction: 1.0,
                                  label: "1",
                                  isBold: false),
                    ],
                    leadingLabel: "Flat",
                    trailingLabel: "Expressive",
                    highlightRange: 0.625...1.0
                )
                explanationText
                Divider()
                audioHighlightSection
                Divider()
                improvementSection
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(white: 0.96).ignoresSafeArea())
        // Native back chevron from the enclosing NavigationStack.
        .navigationTitle("Intonation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.black)
        // Hide the bottom bar (Home / History / Mic) on the review
        // screens so only the native back chevron is available.
        .toolbar(.hidden, for: .bottomBar)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Intonation")
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(.black)
                Text("Vocal Tone")
                    .font(Text.CustomBody)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", pdq))   // raw PDQ in header
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(.black)
                Text("PDQ")
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

    private var audioHighlightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("AUDIO HIGHLIGHT")
            Text("Listen to your most expressive moment — where your pitch varied the most.")
                .font(Text.CustomBody)
                .foregroundStyle(.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if let highlight = result.intonationHighlight, let url = result.audioFileURL {
                AudioHighlightCard(highlight: highlight, audioFileURL: url)
            } else {
                Text("No highlight available.")
                    .font(Text.CustomFootnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
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
        switch pdq {
        case 0.10...:
            return "Your pitch dynamism is expressive (PDQ \(String(format: "%.2f", pdq))). Natural variation keeps listeners engaged and makes key points land harder."
        case 0.05...:
            return "Your pitch has some variation (PDQ \(String(format: "%.2f", pdq))), but there's room to be more expressive. Try emphasising key words with a rise in pitch."
        default:
            return "Your delivery is quite monotone (PDQ \(String(format: "%.2f", pdq))). Flat pitch makes it harder for listeners to stay engaged. Exaggerate your tone on important words."
        }
    }

    private var improvementTips: [String] {
        switch pdq {
        case 0.10...:
            return [
                "Keep varying your pitch naturally — it's already working.",
                "Use a rising tone to signal questions or build suspense.",
                "Lower your pitch at the end of statements to sound confident.",
            ]
        case 0.05...:
            return [
                "Emphasise key words by raising your pitch on them.",
                "Read aloud daily and practice exaggerating your tone up and down.",
                "Record yourself and compare your intonation to a confident speaker.",
            ]
        default:
            return [
                "Read aloud daily and exaggerate your pitch up and down.",
                "Emphasise key words by raising your pitch on them.",
                "Record yourself and compare your intonation to a confident speaker.",
                "Pause before important points — the silence itself adds variety.",
            ]
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        IntonationReviewView(
            result: AnalysisResult(
                transcription: "Selamat pagi, saya ingin mempresentasikan produk kami.",
                duration: 20,
                wordsPerMinute: 120,
                paceLabel: "Normal",
                averageAmplitudeDB: -22,
                volumeLabel: "Good",
                pitchSamples: (0..<100).map { _ in Float.random(in: 80...300) },
                pitchVariance: 800,
                intonationLabel: "Varied",
                amplitudeSamples: [],
                articulationScore: 0.75,
                pronunciationIssues: [],
                audioFileURL: nil,
                intonationHighlight: AudioHighlightSegment(startTime: 3, duration: 12),
                paceHighlight: nil
            )
        )
    }
}
