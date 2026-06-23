//
//  HomeView.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 08/06/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: [SortDescriptor(\RecordingHistoryModel.date, order: .reverse)])
    private var allRecordings: [RecordingHistoryModel]

    @State private var scrollPosition: Int? = 0

    let cardWidth: CGFloat = 300
    let cardSpacing: CGFloat = 12
    let onArticleTap: (Article) -> Void
    let onRecordButtonTap: () -> Void

    init(
        onArticleTap: @escaping (Article) -> Void = { _ in },
        onRecordButtonTap: @escaping () -> Void = {}
    ) {
        self.onArticleTap = onArticleTap
        self.onRecordButtonTap = onRecordButtonTap
    }
    private var analytics: HomeAnalytics {
        HomeAnalytics(recent: allRecordings)
    }

    private var overallPercent: Int {
        Int(((analytics.averageOverallScore ?? 0) * 100).rounded())
    }

   
    private var overallProgressValue: Double {
        Double(overallPercent)
    }

  
    private var categoryLabel: String {
        analytics.scoreCategory?.rawValue.capitalized ?? "—"
    }

    private var pitchPerformanceText: String {
        let category = analytics.scoreCategory?.rawValue ?? "developing"
        return "Your pitching performance demonstrated \(category) delivery, influenced by the paralinguistic aspects below."
    }

    var body: some View {
        if analytics.averageOverallScore == nil {
            emptyState
        } else {
            analyticsContent
        }
    }

    private var emptyState: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 0) {
                    
                    // MARK: – Illustration + prompt
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Text("Start Your Pitch")
                            .font(Text.TitleRegular)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Image(AppImage.homeScreenIllust)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 150)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text("Record a pitch to unlock personalized feedback on your pace, intonation, and articulation.")
                                .font(Text.CustomBody)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button {
                            onRecordButtonTap()
                        } label: {
                            Text("Record Your First Pitch")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 24)

                        Spacer() // Mendorong dari bawah
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .edgesIgnoringSafeArea(.horizontal)
    }

    private var analyticsContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OVERALL ANALYSIS")
                        .font(Text.CustomExpandedSH)
                        .foregroundColor(.gray)
                        .padding(.top)
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(overallPercent)")
                            .customExpandedBT(size: 90)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("%")
                                .customExpandedBT(size: 25)

                            Text(categoryLabel)
                                .font(Text.CustomExpandedT2)
                        }
                        .alignmentGuide(.lastTextBaseline) { d in d[.lastTextBaseline] }

                        Spacer()
                    }

                    PartitionedProgressBar(value: overallProgressValue)

                    Spacer()

                    Text(pitchPerformanceText)
                        .font(Text.CustomBody)
                        .padding(.horizontal)
                        .padding(.bottom, 32)

                    // ── Per-metric cards ────────────────────────────
                    // Only the overall cards carousel is center-aligned
                    // — the rest of the page keeps its original left
                    // alignment.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: cardSpacing) {
                            if let pace = analytics.pace {
                                OverallCard(
                                    title: "Pace",
                                    status: pace.status,
                                    iconName: AppIcon.paceGauge,
                                    pillLabel: pace.pillLabel
                                )
                                .id(0)
                            }
                            if let intonation = analytics.intonation {
                                OverallCard(
                                    title: "Intonation",
                                    status: intonation.status,
                                    iconName: AppIcon.intonation,
                                    pillLabel: intonation.pillLabel
                                )
                                .id(1)
                            }
                            if let articulation = analytics.articulation {
                                OverallCard(
                                    title: "Articulation",
                                    status: articulation.status,
                                    iconName: AppIcon.articulation,
                                    pillLabel: articulation.pillLabel
                                )
                                .id(2)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 16)   // ← replaces contentMargins
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                    .scrollPosition(id: $scrollPosition)
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
                        .foregroundColor(.gray)
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
                            imageName: "PT1",
                            title: "PITCHING TIPS",
                            status: "How To Control Your Speaking Pace Under Pressure"
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onArticleTap(Article.speakingHabits)
                    } label: {
                        ArticleCard(
                            imageName: "PT2",
                            title: "PITCHING TIPS",
                            status: "Common Speaking Habits That Weaken a Pitch"
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onArticleTap(Article.intonationRole)
                    } label: {
                        ArticleCard(
                            imageName: "CF1",
                            title: "COMMUNICATION FUNDAMENTAL",
                            status: "The Role of Intonation in Effective Speaking"
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
                                .fill(Color.PrimaryMainBlue)
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
            overallScore: 1.00,
            pitchSamples: [],
            pitchVariance: 600,
            intonationLabel: "Flat",
            amplitudeSamples: [],
            articulationScore: 1.00,
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
            overallScore: 1.00,
            pitchSamples: [],
            pitchVariance: 400,
            intonationLabel: "Expressive",
            amplitudeSamples: [],
            articulationScore: 1.00,
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
            overallScore: 1.00,
            pitchSamples: [],
            pitchVariance: 250,
            intonationLabel: "Expressive",
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

