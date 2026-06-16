import SwiftUI

// MARK: - App Route
// Single source of truth for the main NavigationStack.
// The stack is bound to `onboardingViewModel.path` and accepts
// `AppRoute` values for the main app. The onboarding flow uses
// `OnboardingStep` values on the same stack — SwiftUI dispatches
// to the matching `navigationDestination(for:)` modifier per type.


enum AppRoute: Hashable {
    case reviewSummary(AnalysisResult)   
    case paceReview(AnalysisResult)
    case articulationReview(AnalysisResult)
    case intonationReview(AnalysisResult)
    case unclearWords([PronunciationIssue], URL?)
    case article(Article)
}

/// Identifies which peer root page the NavigationStack is currently
/// showing. The bottom toolbar uses this to switch between Home and
/// History as independent top-level pages.
enum AppTab: Hashable {
    case home
    case history
}

// MARK: - Article payload
struct Article: Hashable {
    let imageName: String
    let title: String
    let status: String
    let description: String
}

extension Article {
    /// Seed data for the home → article navigation.
    static let pitchingTips = Article(
        imageName: "GreyImg",
        title: "PITCHING TIPS",
        status: "How To Control Your Speaking Pace Under Pressure",
        description: """
Speaking under pressure often causes people to speed up without realizing it. When this happens, listeners may struggle to follow your message, and important points can lose their impact.

One effective way to manage your pace is to use intentional pauses. Brief pauses between ideas give you time to think while allowing listeners to absorb what you have said. Focusing on key messages rather than rushing through every sentence can also help maintain a steady rhythm.

Before an important presentation, practice speaking slightly slower than feels natural. During the presentation, take a breath before introducing a new idea and pause after delivering an important point. These small adjustments can make your speech sound more confident, clear, and engaging, even in high-pressure situations.
"""
    )
}

struct AppRootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    /// Full-screen cover for the recording flow. The cover behaves as
    /// a one-time form: once the user confirms their pitch, the cover
    /// is dismissed and `ReviewSummary` is pushed natively onto the
    /// stack. Back from `ReviewSummary` returns to the peer root
    /// (Home or History) the user was on — never back to the
    /// recording.
    @State private var presentedRecording: Bool = false

    /// Identifies the active peer root page. Switching the tab
    /// replaces the NavigationStack's root with the new page.
    @State private var currentTab: AppTab = .home


    var body: some View {
        // Single NavigationStack bound to the shared path. The root
        // is decided by `currentTab`, so Home and History are peer
        // top-level destinations. Both share the same native path,
        // so any pushed detail (article, review-summary, etc.) is
        // popped by the same back chevron.
        NavigationStack(path: $onboardingViewModel.path) {
            Group {
                if onboardingComplete {
                    if currentTab == .home {
                        HomeView(
                            onArticleTap: { article in
                                onboardingViewModel.path.append(AppRoute.article(article))
                            }
                        )
                    } else {
                        HistoryView(
                            onRecordingTap: { result in
                                onboardingViewModel.path.append(AppRoute.reviewSummary(result))
                            }
                        )
                    }
                } else {
                    OnboardingCoordinatorView(viewModel: onboardingViewModel) {
                        // Reset the shared path and switch into the
                        // main app context.
                        onboardingViewModel.path = NavigationPath()
                        onboardingComplete = true
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        // MARK: - Bottom Bar
        // The bottom bar lives on the main NavigationStack. When the
        // recording full-screen cover is presented, SwiftUI hides the
        // underlying toolbar automatically — no conditional needed.
        .toolbar {
            if shouldShowBottomBar {
                ToolbarItemGroup(placement: .bottomBar) {
                    bottomBarLeading
                    Spacer(minLength: 0)
                    bottomBarTrailing
                }
            }
        }
        .toolbarBackground(.hidden, for: .bottomBar)
        
        // MARK: - Recording (one-time form)
        // Presented as a full-screen cover. The inner NavigationStack
        // gives the recording view a proper navigation bar (title +
        // checkmark + cancel). When the user confirms, the cover
        // dismisses and ReviewSummary is pushed onto the main stack.
        .fullScreenCover(isPresented: $presentedRecording) {
            NavigationStack {
                RecordPitchCoordinatorView(
                    onLanguageConfirmed: {},
                    onFinished: { result in
                        presentedRecording = false
                        onboardingViewModel.path.append(AppRoute.reviewSummary(result))
                    },
                    onCancelled: {
                        presentedRecording = false
                    }
                )
            }
        }
    }
    // MARK: - Destination Resolver

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .reviewSummary(let pitchResult):
                    ReviewSummaryView(result: pitchResult)
         
                case .paceReview(let analysisResult):
                    PaceReviewView(result: analysisResult)
         
                case .articulationReview(let analysisResult):
                    ArticulationReviewView(result: analysisResult)
         
                case .intonationReview(let analysisResult):
                    IntonationReviewView(result: analysisResult)
         
                case .unclearWords(let issues, let url):
                    UnclearWordsView(issues: issues, audioFileURL: url)

        case .article(let article):
            ArticleView(
                imageName: article.imageName,
                title: article.title,
                status: article.status,
                description: article.description
            )
        }
    }

    // MARK: - Bottom Bar Buttons
    
    private var shouldShowBottomBar: Bool {
        onboardingComplete &&
        onboardingViewModel.path.isEmpty
    }

    private var bottomBarLeading: some View {
        HStack(spacing: 6) {
            bottomBarButton(
                systemImage: "house.fill",
                isActive: currentTab == .home
            ) {
                // Switch to the Home peer root. If we're not already
                // on Home, reset the path so the back chevron on
                // any pushed detail returns to Home instead of
                // History.
                if currentTab != .home {
                    currentTab = .home
                    onboardingViewModel.path = NavigationPath()
                }
            }
            bottomBarButton(
                systemImage: "clock.arrow.circlepath",
                isActive: currentTab == .history
            ) {
                // Switch to the History peer root. Reset the path
                // so the back chevron on any pushed detail returns
                // to History instead of the previous root.
                if currentTab != .history {
                    currentTab = .history
                    onboardingViewModel.path = NavigationPath()
                }
            }
        }
        .padding(6)
        .glassEffect(.regular, in: Capsule())
        
        .frame(maxWidth: .infinity)
    }

    private var bottomBarTrailing: some View {
        bottomBarButton(systemImage: AppIcon.micIcon) {
            presentedRecording = true
        }
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private func bottomBarButton(
        systemImage: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppRootView()
}
