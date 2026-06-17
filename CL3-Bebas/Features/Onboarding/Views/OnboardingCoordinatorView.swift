//
//  OnboardingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

// OnboardingCoordinatorView.swift
import SwiftUI

struct OnboardingCoordinatorView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onFinish: () -> Void

    var body: some View {
        // The entire onboarding flow is a clean wizard — no top
        // navigation bar and no bottom toolbar. We use the modern
        // `.toolbar(.hidden, for: .navigationBar)` API (the older
        // `.navigationBarHidden(true)` is deprecated and can be
        // ignored on iOS 17+ when children add toolbar items) and
        // hide the bottom bar explicitly so it never appears in the
        // onboarding wizard.
        WelcomeView(
            onContinue: { viewModel.path.append(OnboardingStep.language) },
            onSkip: { onFinish() }
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .bottomBar)
        .navigationDestination(for: OnboardingStep.self) { step in
            switch step {
            case .welcome:
                EmptyView()
            case .language:
                LanguageSelectionView(
                    selectedLanguage: $viewModel.selectedLanguage,
                    onContinue: { viewModel.path.append(OnboardingStep.quickPitch) }
                )
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .bottomBar)
            case .quickPitch:
                QuickPitchView(viewModel: viewModel)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .bottomBar)
            case .analysing:
                AnalyzingView()
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .bottomBar)
            case .results:
                if let result = viewModel.analysisResult {
                    PitchResultsView(result: result) {
                        onFinish()
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .bottomBar)
                }
            }
        }
    }
}
// MARK: - Preview

#Preview {
    NavigationStack {
        OnboardingCoordinatorView(viewModel: OnboardingViewModel(), onFinish: {})
    }
}
