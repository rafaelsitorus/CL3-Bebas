//
//  UnclearWordsView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 16/06/26.
//



import SwiftUI

struct UnclearWordsView: View {

    // MARK: Properties

    let issues: [PronunciationIssue]
    let audioFileURL: URL?

    /// Only one row expanded at a time. Defaults to the first word.
    @State private var expandedWord: String?

    // MARK: Init

    init(issues: [PronunciationIssue], audioFileURL: URL?) {
        self.issues = issues
        self.audioFileURL = audioFileURL
        _expandedWord = State(initialValue: issues.first?.word)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionLabel("UNCLEAR WORDS")
                Text("These words were pronounced unclear throughout your speech, which may affect message clarity.")
                    .font(Text.CustomBody)
                    .foregroundStyle(.black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                issuesList
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(white: 0.96).ignoresSafeArea())
        // Native back chevron from the enclosing NavigationStack.
        .navigationTitle("Unclear Words")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.black)
        // Hide the bottom bar (Home / History / Mic) on the review
        // screens so only the native back chevron is available.
        .toolbar(.hidden, for: .bottomBar)
    }

    @ViewBuilder
    private var issuesList: some View {
        if issues.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(issues, id: \.word) { issue in
                    UnclearWordRow(
                        issue: issue,
                        audioFileURL: audioFileURL,
                        isExpanded: expandedWord == issue.word,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedWord = (expandedWord == issue.word) ? nil : issue.word
                            }
                        }
                    )
                    if issue.word != issues.last?.word {
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No unclear words detected — nice work!")
                .font(Text.CustomFootnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
    }
}

// MARK: - UnclearWordRow

private struct UnclearWordRow: View {

    let issue: PronunciationIssue
    let audioFileURL: URL?
    let isExpanded: Bool
    let onToggle: () -> Void

    /// Header color: dual-path issues (acoustic ≠ reference) are red
    /// because they represent a confirmed mismatch; legacy low-confidence
    /// issues stay on the default secondary tone.
    private var headerColor: Color {
        issue.isMispronounced ? .red : (isExpanded ? .red : .black)
    }

    /// Only show the "heard: '…'" caption when the dual-path pipeline
    /// told us what the acoustic model actually heard AND it differs
    /// from the reference form.
    private var shouldShowAcousticCaption: Bool {
        guard let acoustic = issue.acousticWord, !acoustic.isEmpty,
              let reference = issue.referenceWord, !reference.isEmpty else {
            return false
        }
        return acoustic.lowercased() != reference.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to expand / collapse
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.word.prefix(1).uppercased() + issue.word.dropFirst())
                            .font(Text.CustomExpandedT2)
                            .foregroundStyle(headerColor)
                        if shouldShowAcousticCaption, let acoustic = issue.acousticWord {
                            Text("Heard: “\(acoustic)”")
                                .font(Text.CustomFootnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.5))
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !issue.sentences.isEmpty {
                Text("LIST OF SENTENCES")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                ForEach(issue.sentences) { sentence in
                    SentencePlaybackCard(
                        sentence: sentence,
                        audioFileURL: audioFileURL ?? sentence.audioFileURL
                    )
                }
            } else {
                Text(issue.suggestion)
                    .font(Text.CustomBody)
                    .foregroundStyle(.black.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 18)
    }
}

// MARK: - SentencePlaybackCard

/// Playback card for a single example sentence. Delegates the play/pause
/// button and progress bar entirely to `AudioPlaybackCard`, removing
/// the previously duplicated `GeometryReader + Capsule + timeString` code.
private struct SentencePlaybackCard: View {

    let sentence: PronunciationExampleSentence
    let audioFileURL: URL?

    @StateObject private var player = SegmentAudioPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Playback bar (reuses AudioPlaybackCard) ─────────────
            AudioPlaybackCard(
                isPlaying: player.isPlaying,
                currentTime: max(0, player.currentTime - sentence.startTime),
                duration: sentence.duration
            ) {
                guard let url = audioFileURL else { return }
                if player.duration == 0 {
                    player.load(url: url, start: sentence.startTime, duration: sentence.duration)
                }
                player.togglePlayback()
            }
            .disabled(audioFileURL == nil)
            .opacity(audioFileURL == nil ? 0.4 : 1)

            // ── Sentence with highlighted word ───────────────────────
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 3)
                    .clipShape(Capsule())

                highlightedText
                    .font(.system(size: 16, design: .default).italic())
                    .foregroundStyle(.black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDisappear {
            player.stop()
        }
    }

    /// Builds sentence text with `highlightedWord` highlighted in red
    /// AND bold. We use `AttributedString` (rather than nested `Text`)
    /// so the colour is preserved inside italic — `Text(…).bold()` does
    /// not allow a custom foreground colour to coexist with the parent
    /// italic context.
    private var highlightedText: Text {
        let text = sentence.text
        let target = sentence.highlightedWord

        guard !target.isEmpty,
              let range = text.range(of: target, options: .caseInsensitive)
        else { return Text(text) }

        var attributed = AttributedString(String(text[text.startIndex..<range.lowerBound]))
        var match = AttributedString(String(text[range]))
        match.foregroundColor = .red
        match.font = .system(size: 16, weight: .bold, design: .default).italic()
        attributed.append(match)
        attributed.append(AttributedString(String(text[range.upperBound...])))

        // Italicise the rest of the sentence too, to match the parent
        // `.italic()` modifier in the call site.
        var full = AttributedString()
        let baseFont = Font.system(size: 16, design: .default).italic()
        for run in attributed.runs {
            var copy = attributed[run.range]
            copy.font = baseFont
            full.append(copy)
        }
        // Re-apply red+bold to the matched run on top of the italic.
        if let matchRun = full.range(of: target, options: .caseInsensitive) {
            full[matchRun].foregroundColor = .red
            full[matchRun].font = .system(size: 16, weight: .bold, design: .default).italic()
        }
        return Text(full)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UnclearWordsView(
            issues: [
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
                        ),
                        PronunciationExampleSentence(
                            text: "I'm going to cooking chicken soup and porridge",
                            highlightedWord: "cooking",
                            audioFileURL: nil,
                            startTime: 3,
                            duration: 20
                        )
                    ]
                ),
                PronunciationIssue(word: "Spinach", timestamp: 8, confidence: 0.5, suggestion: "Unclear pronunciation."),
                PronunciationIssue(word: "Recipe",  timestamp: 12, confidence: 0.6, suggestion: "Unclear pronunciation.")
            ],
            audioFileURL: nil
        )
    }
}
