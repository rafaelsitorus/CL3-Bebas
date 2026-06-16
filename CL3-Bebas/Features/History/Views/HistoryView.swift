//
//  HistoryView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import SwiftUI

struct HistoryView: View {

    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedFilter: FilterOption = .all
    @State private var searchText   = ""
    @State private var isSearchActive = false
    @State private var sortOrder: SortOrder = .newest
    @State private var isSelectMode = false
    @Environment(\.dismiss) private var dismiss

    let onRecordingTap: (AnalysisResult) -> Void

    enum FilterOption: String, CaseIterable {
        case all          = "All"
        case articulation = "Articulation"
        case intonation   = "Intonation"
        case pace         = "Pace"
    }

    enum SortOrder: String {
        case newest = "Default (Newest)"
        case oldest = "Oldest First"
    }

    var filteredRecordings: [RecordingHistory] {
        var result = historyStore.recordings

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

    /// Default analysis result used as a placeholder until each
    /// recording carries its own real metrics.
    private var defaultResult: AnalysisResult {
        AnalysisResult(
            transcription: "",
            duration: 0,
            wordsPerMinute: 0,
            paceLabel: "Too Fast",
            averageAmplitudeDB: -20,
            volumeLabel: "Good",
            pitchSamples: [],
            pitchVariance: 0,
            intonationLabel: "Varied",
            amplitudeSamples: [],
            articulationScore: 0.43,
            pronunciationIssues: [],
            audioFileURL: nil,
            intonationHighlight: nil,
            paceHighlight: nil
        )
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

                // MARK: – Filter Bar
                filterBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // MARK: – Recording List
                LazyVStack(spacing: 0) {
                    ForEach(filteredRecordings) { recording in
                        VStack(spacing: 0) {
                            HistoryCardLink(
                                title: recording.title,
                                date: recording.date,
                                duration: recording.duration,
                                issues: recording.issues,
                                onTap: { onRecordingTap(defaultResult) }
                            )
                            Divider().padding(.leading, 20)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {

            // MARK: – Tombol Search (terpisah)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSearchActive = true   // munculkan search bar + keyboard
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: Circle())
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
                .glassEffect(.regular, in: Circle())
            }
        }
    }

    // MARK: – Filter Bar
    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(FilterOption.allCases.enumerated()), id: \.element) { index, option in
                filterTab(option: option, index: index)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
        )
    }

    @ViewBuilder
    private func filterTab(option: FilterOption, index: Int) -> some View {
        let isSelected  = selectedFilter == option
        let allCases    = FilterOption.allCases
        let nextOption  = index + 1 < allCases.count ? allCases[index + 1] : nil
        let showDivider = !isSelected && (nextOption.map { selectedFilter != $0 } ?? false)

        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedFilter = option
                }
            } label: {
                Text(option.rawValue)
                    .font(Text.CustomFootnote)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)
                        }
                    }
            }
            .buttonStyle(.plain)

            if showDivider {
                Rectangle()
                    .fill(Color(.lightGray))
                    .frame(width: 1, height: 18)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
