//
//  HistoryView.swift
//  CL3-Bebas
//
//  Reads persisted `RecordingHistoryModel` rows straight from
//  SwiftData via `@Query`, so the list always reflects what the
//  user has actually recorded. The previous in-memory
//  `HistoryStore.recordings` (and its hard-coded dummy seed) are
//  gone — `HistoryStore` now only owns the *write* side of the
//  history feature (see `HistoryStore.save(...)`).
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {

    /// All `RecordingHistoryModel` rows, newest first. The query
    /// re-runs automatically when the `ModelContext` is mutated
    /// (e.g. after `HistoryStore.save(...)` is called from
    /// `AppRootView`), so the list updates as soon as a new
    /// recording is inserted — no manual `objectWillChange.send()`
    /// needed.
    @Query(sort: [SortDescriptor(\RecordingHistoryModel.date, order: .reverse)])
    private var recordings: [RecordingHistoryModel]

    @State private var selectedFilter: FilterOption = .all
    @State private var searchText   = ""
    @State private var isSearchActive = false
    @State private var sortOrder: SortOrder = .newest
    @State private var isSelectMode = false
    @Environment(\.dismiss) private var dismiss

    // Focus state for the search bar so the magnifier toolbar
    // button can pop the keyboard up by setting `isSearchActive`
    // and focusing the field in the same transaction.
    @FocusState private var isSearchFieldFocused: Bool

    let onRecordingTap: (AnalysisResult) -> Void

    enum FilterOption: String, CaseIterable, Identifiable {
        case all          = "All"
        case articulation = "Articulation"
        case intonation   = "Intonation"
        case pace         = "Pace"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all:          return "list.bullet"
            case .articulation: return "person.wave.2"
            case .intonation:   return "waveform.path"
            case .pace:         return "timer"
            }
        }
    }

    enum SortOrder: String {
        case newest = "Default (Newest)"
        case oldest = "Oldest First"
    }

    /// View-side filter / search / sort pipeline. Runs over the
    /// `@Query` results so the SwiftData store stays untouched.
    private var filteredRecordings: [RecordingHistoryModel] {
        var result = recordings

        // 1. Filter by category
        if selectedFilter != .all {
            result = result.filter { recording in
                switch selectedFilter {
                case .all:          return true
                case .articulation: return recording.issues.contains(.articulation)
                case .intonation:   return recording.issues.contains(.intonation)
                case .pace:         return recording.issues.contains(.pace)
                }
            }
        }

        // 2. Filter by search query
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 3. Sort
        switch sortOrder {
        case .newest: result.sort { $0.date > $1.date }
        case .oldest: result.sort { $0.date < $1.date }
        }

        return result
    }

    init(onRecordingTap: @escaping (AnalysisResult) -> Void = { _ in }) {
        self.onRecordingTap = onRecordingTap
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: – Custom Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALL PITCHING")
                        .font(Text.CustomExpandedSH)
                        .foregroundStyle(.secondary)
                    Text("History")
                        .font(Text.TitleRegular)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // MARK: – Search Bar
                if isSearchActive {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(
                            "Search recordings",
                            text: $searchText
                        )
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: – Filter Bar
                filterBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // MARK: – Empty state
                // First-launch experience: instead of seeding dummy
                // rows, we just tell the user to record their first
                // pitch. The empty state disappears as soon as one
                // row is inserted via `HistoryStore.save(...)`.
                if filteredRecordings.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No recordings yet")
                            .font(Text.CustomHeadline)
                            .foregroundStyle(.primary)
                        Text("Tap the mic to record your first pitch — it will appear here automatically.")
                            .font(Text.CustomFootnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }

                // MARK: – Recording List
                LazyVStack(spacing: 0) {
                    ForEach(filteredRecordings) { recording in
                        VStack(spacing: 0) {
                            HistoryCardLink(
                                title: recording.title,
                                date: recording.date,
                                duration: recording.duration,
                                scorePercent: recording.overallScorePercent,
                                labels: buildLabels(for: recording),
                                onTap: { onRecordingTap(recording.toAnalysisResult()) }
                            )
                            Divider().padding(.leading, 20)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {

            // MARK: – Tombol Search (terpisah)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSearchActive = true
                    DispatchQueue.main.async {
                        isSearchFieldFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
            }

            // MARK: – Tombol Menu (terpisah)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {

                    // ── Select ──────────────────────────────────
                    Button {
                        isSelectMode.toggle()
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }

                    // ── Sort By (submenu → ">" muncul otomatis) ─
                    Menu {
                        Button {
                            withAnimation { sortOrder = .newest }
                        } label: {
                            if sortOrder == .newest {
                                Label("Default (Newest)", systemImage: "checkmark")
                            } else {
                                Text("Default (Newest)")
                            }
                        }

                        Button {
                            withAnimation { sortOrder = .oldest }
                        } label: {
                            if sortOrder == .oldest {
                                Label("Oldest First", systemImage: "checkmark")
                            } else {
                                Text("Oldest First")
                            }
                        }
                    } label: {
                        Label("Sort By", systemImage: "arrow.up.arrow.down")
                    }

                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: – Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FilterOption.allCases) { option in
                    filterChip(option: option)
                }
            }
        }
    }

    @ViewBuilder
    private func filterChip(option: FilterOption) -> some View {
        let isSelected = selectedFilter == option

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedFilter = option
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(option.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.TextAppColor : Color(.systemGray6))
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Label Builder

    /// Build the coloured label descriptors for a single recording row.
    /// Each label shows "Category: Value" with colours that match the
    /// ReviewSummary scheme (green = good, red = needs improvement).
    private func buildLabels(for recording: RecordingHistoryModel) -> [HistoryLabelInfo] {
        var labels: [HistoryLabelInfo] = []

        // Intonation
        let intonation = recording.intonationColors
        labels.append(HistoryLabelInfo(
            text: "Intonation: \(recording.intonationLabel)",
            foregroundColor: intonation.foreground,
            backgroundColor: intonation.background
        ))

        // Articulation
        let articulation = recording.articulationColors
        labels.append(HistoryLabelInfo(
            text: "Articulation: \(recording.articulationDisplayLabel)",
            foregroundColor: articulation.foreground,
            backgroundColor: articulation.background
        ))

        // Pace
        let pace = recording.paceColors
        labels.append(HistoryLabelInfo(
            text: "Pace: \(recording.paceLabel)",
            foregroundColor: pace.foreground,
            backgroundColor: pace.background
        ))

        return labels
    }
}

#Preview {
    // In-memory SwiftData container so the preview renders without
    // touching the on-disk store. We seed two rows so the list
    // previews against real data.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: RecordingHistoryModel.self,
        configurations: config
    )
    let context = ModelContext(container)
    let now = Date()
    context.insert(RecordingHistoryModel(
        title: "Recording 1",
        date: now,
        duration: 510,
        issues: [.intonation, .articulation, .pace],
        languageCode: "en",
        transcription: "Sample pitch transcript",
        wordsPerMinute: 145,
        paceLabel: "Ideal",
        averageAmplitudeDB: -20,
        volumeLabel: "Good",
        overallScore: 0.82,
        pitchSamples: (0..<100).map { _ in Float.random(in: 80...300) },
        pitchVariance: 600,
        intonationLabel: "Varied",
        amplitudeSamples: (0..<100).map { _ in Float.random(in: -45 ... -10) },
        articulationScore: 0.78,
        pronunciationIssues: [],
        intonationHighlight: AudioHighlightSegment(startTime: 4, duration: 10),
        paceHighlight: AudioHighlightSegment(startTime: 30, duration: 15),
        audioFileRelativePath: nil
    ))
    context.insert(RecordingHistoryModel(
        title: "Recording 2",
        date: now.addingTimeInterval(-86_400),
        duration: 320,
        issues: [.volume],
        languageCode: "id",
        transcription: "Halo semua",
        wordsPerMinute: 110,
        paceLabel: "Slow",
        averageAmplitudeDB: -45,
        volumeLabel: "Too Quiet",
        overallScore: 0.55,
        pitchSamples: (0..<80).map { _ in Float.random(in: 100...200) },
        pitchVariance: 200,
        intonationLabel: "Flat",
        amplitudeSamples: (0..<80).map { _ in Float.random(in: -60 ... -40) },
        articulationScore: 0.62,
        pronunciationIssues: [],
        intonationHighlight: nil,
        paceHighlight: nil,
        audioFileRelativePath: nil
    ))
    try? context.save()

    return NavigationStack {
        HistoryView()
            .modelContainer(container)
    }
}
