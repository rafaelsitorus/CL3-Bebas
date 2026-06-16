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

    /// Shared store of recordings. Injected as an environment object
    /// so any view (History, recording flow) can read or write.
    @StateObject private var historyStore = HistoryStore()

    /// Full-screen cover for the recording flow. Acts as a one-time
    /// form. When the user confirms, the cover dismisses and a
    /// `ReviewSummary` is pushed onto the main stack with a dummy
    /// `AnalysisResult`, and a new `RecordingHistory` is appended to
    /// the shared store.
    @State private var presentedRecording: Bool = false

    /// Identifies the active peer root page. Switching the tab
    /// replaces the NavigationStack's root with the new page.
    @State private var currentTab: AppTab = .home

    /// Number of recordings completed so far — used to derive the
    /// next recording's title.
    @State private var recordingsCounter: Int = 0

    // MARK: - Body

    var body: some View {
        // Single NavigationStack bound to the shared path. The root
        // is decided by `currentTab`, so Home and History are peer
        // top-level destinations. Both share the same native path,
        // so any pushed detail (article, review-summary, etc.) is
        // popped by the same back chevron.
        NavigationStack(path: $onboardingViewModel.path) {
            rootContent
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        // Inject the history store into the environment so child
        // views (recording flow, history) can read/write to it.
        .environmentObject(historyStore)
        // MARK: - Bottom Bar
        // The bottom bar lives on the main NavigationStack. We only
        // attach its toolbar items once onboarding is complete so
        // the onboarding flow stays a clean wizard. (Just hiding
        // via `.toolbar(.hidden, for: .bottomBar)` was not enough —
        // the items were still declared and the bar leaked through.)
        .toolbar {
            // Show the bottom bar only on the peer-root pages
            // (Home, History). Hide it on every review / analysis
            // destination so the user only sees the native back
            // chevron when reading review content.
            if onboardingComplete && shouldShowBottomBar {
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
            // The recording cover is a one-time form. We give it
            // its own NavigationStack so each inner view can declare
            // a navigation title + toolbar items (the checkmark and
            // back chevron), and then we hide BOTH the default system
            // back chevron and the inherited bottom toolbar so the
            // cover is a clean full-screen sheet with only the
            // intentional toolbar items the inner views declare.
            NavigationStack {
                RecordPitchCoordinatorView(
                    onLanguageConfirmed: {},
                    onFinished: { _, langCode in
                        // Dismiss cover first, then push a fresh
                        // ReviewSummary with a dummy AnalysisResult
                        // so the rest of the navigation flow can be
                        // demonstrated end-to-end.
                        presentedRecording = false

                        // Build a fresh, deterministic dummy result
                        // seeded from the language the user picked.
                        let result = makeDummyAnalysisResult(
                            languageCode: langCode
                        )

                        // Append a new entry to the shared history
                        // store so the user can see it in the
                        // History tab right away.
                        recordingsCounter += 1
                        historyStore.append(
                            RecordingHistory(
                                title: "Recording \(recordingsCounter)",
                                date: .now,
                                duration: 30,
                                issues: inferIssues(from: result)
                            )
                        )

                        // Push the freshly-built ReviewSummary onto
                        // the main NavigationStack.
                        onboardingViewModel.path.append(
                            AppRoute.reviewSummary(result)
                        )
                    },
                    onCancelled: {
                        presentedRecording = false
                    }
                )
            }
            .toolbar(.hidden, for: .bottomBar)
        }
    }

    // MARK: - Root Content

    /// Returns `true` when the user is on a peer-root page (Home /
    /// History) and `false` while on a pushed review / analysis
    /// destination. The bottom bar is rendered on the NavigationStack
    /// itself, so it appears for every pushed page by default.
    /// Because the only destinations we ever push from the root
    /// pages are the review screens (Review Summary, Pace,
    /// Articulation, Intonation, Unclear Words) and the article
    /// detail page, we just check whether the path is empty: if
    /// it's empty we're on a peer root, otherwise we're on a
    /// pushed review destination.
    private var shouldShowBottomBar: Bool {
        onboardingViewModel.path.isEmpty
    }

    @ViewBuilder
    private var rootContent: some View {
        if !onboardingComplete {
            OnboardingCoordinatorView(viewModel: onboardingViewModel) {
                // Reset the shared path and switch into the
                // main app context.
                onboardingViewModel.path = NavigationPath()
                onboardingComplete = true
            }
        } else if currentTab == .home {
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

    // MARK: - Dummy Analysis

    /// Build a placeholder `AnalysisResult` so the entire
    /// post-recording flow (ReviewSummary → Pace / Articulation /
    /// Intonation → Unclear Words) can be demonstrated end-to-end
    /// even before the real analyzer is wired up. The values are
    /// deterministic so repeated runs give the same experience.
    private func makeDummyAnalysisResult(languageCode: String) -> AnalysisResult {
        AnalysisResult(
            transcription: languageCode == "en"
                ? "Hello, I am excited to share my idea with you today."
                : "Halo, saya senang dapat membagikan ide saya hari ini.",
            duration: 30,
            wordsPerMinute: 145,
            paceLabel: "Ideal",
            averageAmplitudeDB: -22,
            volumeLabel: "Good",
            pitchSamples: (0..<100).map { i in
                150 + 40 * sin(Float(i) / 5)
            },
            pitchVariance: 1200,
            intonationLabel: "Varied",
            amplitudeSamples: (0..<100).map { i in
                -20 + 8 * sin(Float(i) / 3)
            },
            articulationScore: 0.78,
            pronunciationIssues: [
                PronunciationIssue(
                    word: "excited",
                    timestamp: 4,
                    confidence: 0.55,
                    suggestion: "Try emphasising both syllables."
                ),
                PronunciationIssue(
                    word: "today",
                    timestamp: 12,
                    confidence: 0.62,
                    suggestion: "The final syllable could be clearer."
                )
            ],
            audioFileURL: nil,
            intonationHighlight: AudioHighlightSegment(startTime: 5, duration: 10),
            paceHighlight: AudioHighlightSegment(startTime: 0, duration: 15)
        )
    }

    /// Maps the dummy result's flags to the badges shown in the
    /// history card.
    private func inferIssues(from result: AnalysisResult) -> [SpeechIssue] {
        var issues: [SpeechIssue] = []
        if result.articulationScore < 0.85 { issues.append(.articulation) }
        if result.intonationLabel != "Varied" { issues.append(.intonation) }
        if result.paceLabel != "Ideal" && result.paceLabel != "Normal" {
            issues.append(.pace)
        }
        issues.append(.volume) // dummy recordings always carry volume
        return issues
    }

    // MARK: - Bottom Bar Buttons

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
