//
//  LabelColor+Extension.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//


import SwiftUI

extension PitchAnalysisResult.PaceRating {
    var labelColor: Color {
        switch self {
        case .good: return .BluePrimaryBC
        case .tooFast, .tooSlow: return .RedPrimarySC
        }
    }
}

extension PitchAnalysisResult.ArticulationRating {
    var labelColor: Color {
        switch self {
        case .clear, .veryClear: return .BluePrimaryBC
        case .unclear: return .RedPrimarySC
        }
    }
}

extension PitchAnalysisResult.IntonationRating {
    var labelColor: Color {
        switch self {
        case .expressive, .varied: return .BluePrimaryBC
        case .flat: return .RedPrimarySC
        }
    }
}
