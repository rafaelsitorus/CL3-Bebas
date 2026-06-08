//
//  OnboardingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

// OnboardingCoordinatorView.swift
import SwiftUI

struct OnboardingCoordinatorView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    var onFinish: () -> Void

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            WelcomeView(
                onContinue: { viewModel.path.append(OnboardingStep.language) },
                onSkip: { onFinish() }
            )
            .navigationBarHidden(true)
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .welcome:
                    EmptyView()
                case .language:
                    LanguageSelectionView(
                        selectedLanguage: $viewModel.selectedLanguage,
                        onContinue: { viewModel.path.append(OnboardingStep.quickPitch) }
                    )
                    .navigationBarHidden(true)
                case .quickPitch:
                    QuickPitchView(viewModel: viewModel)
                        .navigationBarHidden(true)
                case .analysing:
                    AnalyzingView()
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true)
                case .results:
                    if let result = viewModel.analysisResult {
                        PitchResultsView(result: result) {
                            onFinish()
                        }
                        .navigationBarHidden(true)
                    }
                }
            }
        }
    }
}
// MARK: - Preview

#Preview {
    OnboardingCoordinatorView(onFinish: {})
}
