//
//  ReviewSummaryViewModel.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//


import SwiftUI
import Combine

@MainActor
final class ReviewSummaryViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isPlaying: Bool = false

    // MARK: - Data

    let result: PitchAnalysisResult

    let sampleLevels: [CGFloat] = (0..<50).map { _ in CGFloat.random(in: 0.1...1.0) }

    // MARK: - Init

    init(result: PitchAnalysisResult) {
        self.result = result
    }

    // MARK: - Computed Metric Props

    var intonationProgress: Double { 0.75 }
    var paceProgress: Double { 0.35 }
    var articulationProgress: Double { 0.3 }

    // MARK: - Actions

    func togglePlayback() {
        isPlaying.toggle()
    }
}
