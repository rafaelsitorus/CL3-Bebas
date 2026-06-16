import SwiftUI

struct PaceReviewView: View {

    let result: AnalysisResult

    @Environment(\.dismiss) private var dismiss

    // Map WPM 60–200 linearly to 0–1
    private var paceCurrentFraction: Double {
        let wpm = max(60.0, min(200.0, result.wordsPerMinute))
        return (wpm - 60) / (200 - 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                backButton
                sectionLabel("ANALYSIS")
                headerRow
                AnalysisScaleView(
                    fraction: paceCurrentFraction,
                    ticks: [
                        ScaleTick(fraction: 0.0,                label: "60",                          isBold: false),
                        ScaleTick(fraction: 0.5,                label: "130",                         isBold: false),
                        ScaleTick(fraction: 0.714,              label: "160",                         isBold: false),
                        ScaleTick(fraction: paceCurrentFraction, label: "\(Int(result.wordsPerMinute))", isBold: true),
                        ScaleTick(fraction: 1.0,                label: "200",                         isBold: false),
                    ],
                    leadingLabel: "Too Slow",
                    trailingLabel: result.wordsPerMinute > 160 ? "Too Fast" : "Normal",
                    highlightRange: 0.5...0.714
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
                Text("Pace")
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(.black)
                Text("Speaking Speed")
                    .font(Text.CustomBody)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f", result.wordsPerMinute))
                    .font(Text.CustomLargeTitle)
                    .foregroundStyle(.black)
                Text("WPM")
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
            Text("Listen to your best-paced section — where your speaking speed was closest to the ideal range.")
                .font(Text.CustomBody)
                .foregroundStyle(.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if let highlight = result.paceHighlight, let url = result.audioFileURL {
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
    }

    // MARK: Copy

    private var explanation: String {
        switch result.paceLabel {
        case "Too Slow":
            return "You're speaking very slowly at \(Int(result.wordsPerMinute)) WPM. While clarity matters, too slow a pace can lose your listener's attention. Aim for at least 110 WPM."
        case "Slow":
            return "Your pace of \(Int(result.wordsPerMinute)) WPM is a little below the ideal range. Picking up slightly will help keep your audience engaged."
        case "Normal", "Ideal":
            return "Your pace of \(Int(result.wordsPerMinute)) WPM is right in the sweet spot. Listeners can follow your ideas comfortably without feeling rushed."
        case "Fast":
            return "At \(Int(result.wordsPerMinute)) WPM you're moving quickly. Slowing down slightly gives listeners time to absorb each point before you move on."
        default:
            return "At \(Int(result.wordsPerMinute)) WPM you're speaking very fast — listeners may struggle to keep up. Pause between key ideas to let them land."
        }
    }

    private var improvementTips: [String] {
        switch result.paceLabel {
        case "Too Slow", "Slow":
            return [
                "Practice with a metronome app, targeting 120–140 WPM.",
                "Read a paragraph aloud and time yourself — aim for 1 minute per ~130 words.",
                "Reduce long silences between sentences; pause intentionally, not habitually.",
            ]
        case "Normal", "Ideal":
            return [
                "Maintain your current pace — it's already ideal.",
                "Use deliberate pauses before key points for extra emphasis.",
                "Vary your speed slightly: slow down for complex ideas, speed up for familiar ones.",
            ]
        default:
            return [
                "Practice pausing for 1–2 seconds after each key point.",
                "Record yourself and listen back at 0.75× speed to hear the gaps you're skipping.",
                "Mark pause symbols (///) in your notes to build in natural rests.",
                "Breathe fully between sentences — it naturally slows your pace.",
            ]
        }
    }
}

#Preview {
    NavigationStack {
        PaceReviewView(
            result: AnalysisResult(
                transcription: "Selamat pagi, saya ingin mempresentasikan produk kami.",
                duration: 20,
                wordsPerMinute: 175,
                paceLabel: "Too Fast",
                averageAmplitudeDB: -22,
                volumeLabel: "Good",
                pitchSamples: [],
                pitchVariance: 600,
                intonationLabel: "Varied",
                amplitudeSamples: [],
                articulationScore: 0.75,
                pronunciationIssues: [],
                audioFileURL: nil,
                intonationHighlight: nil,
                paceHighlight: AudioHighlightSegment(startTime: 5, duration: 12)
            )
        )
    }
}
