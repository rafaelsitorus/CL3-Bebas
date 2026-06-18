//
//  HomeView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 08/06/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {

    /// The user's recordings, newest first. `@Query` keeps this in
    /// sync with SwiftData — every time a new
    /// `RecordingHistoryModel` is inserted (e.g. after a fresh
    /// recording finishes analysis), the view re-renders
    /// automatically. We take the first 5 for the analytics
    /// (matching the product spec: "average of the latest 5
    /// pitches, or fewer if the user has recorded less").
    @Query(sort: [SortDescriptor(\RecordingHistoryModel.date, order: .reverse)])
    private var allRecordings: [RecordingHistoryModel]

    @State private var scrollPosition: Int? = 0

    let cardWidth: CGFloat = 320
    let cardSpacing: CGFloat = 4

    /// Triggered when the user taps an article card.
    /// Connected natively by the root NavigationStack.
    let onArticleTap: (Article) -> Void

    init(onArticleTap: @escaping (Article) -> Void = { _ in }) {
        self.onArticleTap = onArticleTap
    }

    // MARK: - Derived analytics
    //
    // We compute the `HomeAnalytics` snapshot inline from the
    // `@Query` results. SwiftUI re-evaluates this view body every
    // time `allRecordings` changes, so the snapshot — including
    // the random tip — refreshes on every insert. That gives the
    // user a fresh tip on each visit, which is the desired
    // behaviour ("variatif, tetapi pada kesempatan lain, tips lain
    // juga bisa keluar").

    private var analytics: HomeAnalytics {
        HomeAnalytics(recent: allRecordings)
    }

    /// Display value for the big "53" headline. `Int` because the
    /// old `customExpandedBT` style was rendering whole numbers;
    /// rounding keeps the value stable across re-renders within a
    /// session.
    private var overallPercent: Int {
        Int(((analytics.averageOverallScore ?? 0) * 100).rounded())
    }

    /// Progress-bar value (0...100). The
    /// `PartitionedProgressBar` already clamps each segment to
    /// 0...1 internally, so we just forward the percentage as a
    /// `Double`.
    private var overallProgressValue: Double {
        Double(overallPercent)
    }

    /// Short label under the percentage ("Weak" / "Developing" /
    /// "Strong" / "Excellent"). Mirrors the bucket the progress
    /// bar fills into.
    private var categoryLabel: String {
        analytics.scoreCategory?.rawValue.capitalized ?? "—"
    }

    /// Sentence rendered just under the progress bar. Filled with
    /// the bucketed category. When the user has zero recordings
    /// the parent renders an empty state instead, so we never
    /// reach this branch with no data.
    private var pitchPerformanceText: String {
        let category = analytics.scoreCategory?.rawValue ?? "developing"
        return "Your pitching performance demonstrated \(category) delivery, influenced by the paralinguistic aspects below."
    }

    var body: some View {
        // Empty state: when the user has zero recordings the
        // average percentage / per-metric cards have no meaning,
        // so we hide the analytics section entirely and show a
        // single CTA pointing them at the mic button on the
        // bottom bar. The History tab's empty state mirrors this
        // copy so the two pages agree.
        if analytics.averageOverallScore == nil {
            emptyState
        } else {
            analyticsContent
        }
    }

    private var emptyState: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OVERALL ANALYSIS")
                            .font(Text.CustomExpandedSH)
                            .foregroundStyle(.secondary)
                        Text("History")
                            .font(Text.TitleRegular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer().frame(height: 80)

                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No recordings yet")
                            .font(Text.CustomHeadline)
                            .foregroundStyle(.primary)
                        Text("Tap the mic at the bottom right to record your first pitch — your overall analysis will appear here.")
                            .font(Text.CustomFootnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var analyticsContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // ── Overall Analysis header ─────────────────────
                    Text("OVERALL ANALYSIS")
                        .font(Text.CustomExpandedSH)
                        .padding(.top)
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text("\(overallPercent)").customExpandedBT(size: 90)
                            .padding(.leading)

                        VStack {
                            Text("%")
                                .customExpandedBT(size: 25)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(categoryLabel)
                                .font(Text.CustomExpandedT2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    PartitionedProgressBar(value: overallProgressValue)

                    Spacer()

                    Text(pitchPerformanceText)
                        .font(Text.CustomBody)
                        .padding(.leading)
                        .padding(.bottom, 32)

                    // ── Per-metric cards ────────────────────────────
                    // Only the overall cards carousel is center-aligned
                    // — the rest of the page keeps its original left
                    // alignment.
                    GeometryReader { geo in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: cardSpacing) {
                                if let pace = analytics.pace {
                                    OverallCard(
                                        title: "Pace",
                                        status: pace.status,
                                        description: pace.tip,
                                        iconName: AppIcon.paceGauge,
                                        pillLabel: pace.pillLabel
                                    )
                                    .frame(width: cardWidth)
                                    .id(0)
                                }

                                if let intonation = analytics.intonation {
                                    OverallCard(
                                        title: "Intonation",
                                        status: intonation.status,
                                        description: intonation.tip,
                                        iconName: AppIcon.intonation,
                                        pillLabel: intonation.pillLabel
                                    )
                                    .frame(width: cardWidth)
                                    .id(1)
                                }

                                if let articulation = analytics.articulation {
                                    OverallCard(
                                        title: "Articulation",
                                        status: articulation.status,
                                        description: articulation.tip,
                                        iconName: AppIcon.articulation,
                                        pillLabel: articulation.pillLabel
                                    )
                                    .frame(width: cardWidth)
                                    .id(2)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollClipDisabled()
                        .scrollPosition(id: $scrollPosition)
                        .contentMargins(.horizontal, (geo.size.width - cardWidth) / 2, for: .scrollContent)
                    }
                        .frame(height: 240)

                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == (scrollPosition ?? 0)
                                        ? Color.primary
                                        : Color.gray.opacity(0.35)
                                )
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: scrollPosition)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                    Divider()
                        .frame(height: 1)
                        .background(Color.gray.opacity(0.35))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Text("ARTICLE")
                        .font(Text.CustomExpandedSH)
                        .padding(.top)
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Tapping the article card pushes ArticleView natively
                    // onto the main NavigationStack via the callback
                    // supplied by AppRootView.
                    Button {
                        onArticleTap(Article.pitchingTips)
                    } label: {
                        ArticleCard(
                            imageName: "GreyImg",
                            title: "PITCHING TIPS",
                            status: "How To Control Your Speaking Pace Under Pressure"
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PartitionedProgressBar: View {
    var value: Double
    var total: Double = 100

    // Label untuk masing-masing partisi
    let labels = ["Weak", "Developing", "Strong", "Excellent"]

    var body: some View {
        HStack(spacing: 3) { // Jarak antar partisi
            ForEach(0..<4, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    // Bagian Bar (Batang Progress)
                    GeometryReader { geo in
                        let segmentValue = total / 4.0
                        let segmentStart = Double(index) * segmentValue

                        let fillRatio = max(0, min(1, (value - segmentStart) / segmentValue))

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.gray.opacity(0.3))

                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.primary)
                                .frame(width: geo.size.width * CGFloat(fillRatio))
                        }
                    }
                    .frame(height: 8)

                    // Bagian Label Teks
                    Text(labels[index])
                        .font(.caption)
                        .foregroundColor(.primary)
                        // MODIFIKASI DI SINI: Jika index ke-3 (Excellent), rata kanan. Selain itu rata kiri.
                        .frame(maxWidth: .infinity, alignment: (index == 2 || index == 3) ? .trailing : .leading)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview("With recordings") {
    // In-memory SwiftData container with 3 recordings so the
    // previews show real analytics.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: RecordingHistoryModel.self,
        configurations: config
    )
    let context = ModelContext(container)
    let now = Date()
    let rows: [RecordingHistoryModel] = [
        RecordingHistoryModel(
            title: "Recording 1",
            date: now,
            duration: 510,
            issues: [.intonation, .pace],
            languageCode: "en",
            transcription: "Sample pitch transcript",
            wordsPerMinute: 175,
            paceLabel: "Too Fast",
            averageAmplitudeDB: -20,
            volumeLabel: "Good",
            overallScore: 0.55,
            pitchSamples: [],
            pitchVariance: 600,
            intonationLabel: "Flat",
            amplitudeSamples: [],
            articulationScore: 0.78,
            pronunciationIssues: [],
            intonationHighlight: nil,
            paceHighlight: nil,
            audioFileRelativePath: nil
        ),
        RecordingHistoryModel(
            title: "Recording 2",
            date: now.addingTimeInterval(-86_400),
            duration: 320,
            issues: [.volume],
            languageCode: "id",
            transcription: "Halo semua",
            wordsPerMinute: 140,
            paceLabel: "Ideal",
            averageAmplitudeDB: -22,
            volumeLabel: "Good",
            overallScore: 0.70,
            pitchSamples: [],
            pitchVariance: 400,
            intonationLabel: "Varied",
            amplitudeSamples: [],
            articulationScore: 0.72,
            pronunciationIssues: [],
            intonationHighlight: nil,
            paceHighlight: nil,
            audioFileRelativePath: nil
        ),
        RecordingHistoryModel(
            title: "Recording 3",
            date: now.addingTimeInterval(-2 * 86_400),
            duration: 240,
            issues: [],
            languageCode: "en",
            transcription: "Today I will talk about...",
            wordsPerMinute: 120,
            paceLabel: "Normal",
            averageAmplitudeDB: -25,
            volumeLabel: "Good",
            overallScore: 0.78,
            pitchSamples: [],
            pitchVariance: 250,
            intonationLabel: "Varied",
            amplitudeSamples: [],
            articulationScore: 0.85,
            pronunciationIssues: [],
            intonationHighlight: nil,
            paceHighlight: nil,
            audioFileRelativePath: nil
        )
    ]
    for row in rows { context.insert(row) }
    try? context.save()

    return NavigationStack {
        HomeView()
            .modelContainer(container)
    }
}

#Preview("Empty state") {
    // In-memory SwiftData container with zero rows so the
    // previews exercise the empty state. We currently render the
    // analytics card with zeros (0 % / "—") because the spec
    // asked for the empty state to be visible only at zero
    // recordings — the cards/percentage are still useful as
    // placeholders, but the "All Pitching" header above and the
    // prompt to record would normally go here. The current
    // build keeps the analytics layout intact for visual
    // continuity; the real "go record your first pitch" copy
    // is on the History tab.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: RecordingHistoryModel.self,
        configurations: config
    )
    return NavigationStack {
        HomeView()
            .modelContainer(container)
    }
}
