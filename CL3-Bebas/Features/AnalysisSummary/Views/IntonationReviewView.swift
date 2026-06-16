//
//  IntonationReviewView.swift


import SwiftUI

struct IntonationReviewView: View {

    // MARK: Properties

    let result: AnalysisResult

    // MARK: Private

    /// Standard deviation of pitch samples in Hz.
    private var pitchSD: Float {
        sqrt(result.pitchVariance)
    }

    /// Map pitch SD → 0–1 for the scale.
    /// Flat < 20 Hz SD → near 0. Expressive > 20 Hz SD → toward 1. Capped at 80 Hz.
    private var scaleFraction: Double {
        Double(max(0, min(1, pitchSD / 80)))
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sectionLabel("ANALYSIS")
                headerRow
                AnalysisScaleView(
                    fraction: scaleFraction,
                    tickLabel: String(format: "±%.0f Hz", pitchSD),
                    leadingLabel: "Expressive",
                    trailingLabel: "Flat"
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
                Text(String(format: "±%.0f", pitchSD))
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(.black)
                Text("Hz SD")
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
        result.intonationLabel == "Varied"
            ? "Your pitch varied naturally throughout the recording, making your speech sound engaging and dynamic. Listeners are less likely to zone out when the speaker uses expressive intonation."
            : "Your pitch stayed relatively flat throughout the recording. Monotone delivery can make listeners disengage. Try raising your voice on key points and lowering it at natural pauses."
    }

    private var improvementTips: [String] {
        result.intonationLabel == "Varied"
            ? [
                "Keep varying your pitch naturally — it's already working.",
                "Use a rising tone to signal questions or build suspense.",
                "Lower your pitch at the end of statements to sound confident.",
              ]
            : [
                "Read aloud daily and exaggerate your pitch up and down.",
                "Emphasise key words by raising your pitch on them.",
                "Record yourself and compare your intonation to a confident speaker.",
                "Pause before important points — the silence itself adds variety.",
              ]
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
