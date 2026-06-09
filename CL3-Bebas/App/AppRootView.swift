import SwiftUI

enum AppRoute: Hashable {
    case recordingCoordinatorView
    case recordingReviewSummary
    case paceReview
}

struct AppRootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var recordingViewModel = RecordPitchViewModel()

    var body: some View {
        NavigationStack(path: $onboardingViewModel.path) {
            if onboardingComplete {
                // Tampilan root saat ini
                HomeView(
                    recordingViewModel: recordingViewModel,
                    onRecordTap: {
                        // Menambahkan rute ke dalam tumpukan (stack)
                        onboardingViewModel.path.append(AppRoute.recordingCoordinatorView)
                    },
                    onPaceTap: {
                        onboardingViewModel.path.append(AppRoute.paceReview)
                    }
                )
                // Menangkap perubahan rute dan merender View yang sesuai
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .recordingReviewSummary:
                        ReviewSummaryView(
                            result: PitchAnalysisResult(
                                pace: .tooFast,
                                articulation: .unclear,
                                intonation: .expressive
                            ),
                            onContinue: {},
                            onPaceTap: {
                                onboardingViewModel.path.append(AppRoute.paceReview)
                            }
                        )
                    case .paceReview: // <- Definisikan tampilan untuk rute baru
                        PaceReviewView()
                    case .recordingCoordinatorView:
                        RecordPitchCoordinatorView()
                    }
                }
            } else {
                OnboardingCoordinatorView(viewModel: onboardingViewModel) {
                    onboardingViewModel.path = NavigationPath()
                    onboardingComplete = true
                }
            }
        }
    }
}

#Preview {
    AppRootView()
}
