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
    @State private var isAnalyzing: Bool = false
    @State private var analyzer = SpeechAnalyzer()
    
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
        .background(Color.lightGrayBC)
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
        // Show the iOS native liquid-glass material behind the
        // bottom bar. SwiftUI draws the native hover / press
        // highlight around each tap target on top of this
        // material, which is the same look used by Apple Health
        // and other first-party iOS apps.
        .toolbarBackground(.visible, for: .bottomBar)

        // MARK: - Recording (one-time form)
        // Presented as a full-screen cover. The inner NavigationStack
        // gives the recording view a proper navigation bar (title +
        // checkmark + cancel). When the user confirms, we keep the
        // cover open and present the AnalyzingRecordingView on top
        // of the recording pages. Once analysis finishes the cover
        // is dismissed and ReviewSummary is pushed onto the main
        // NavigationStack.
        .fullScreenCover(isPresented: $presentedRecording) {
            // The recording cover is a one-time form. We give it
            // its own NavigationStack so each inner view can declare
            // a navigation title + toolbar items (the checkmark and
            // back chevron), and then we hide BOTH the default system
            // back chevron and the inherited bottom toolbar so the
            // cover is a clean full-screen sheet with only the
            // intentional toolbar items the inner views declare.
            ZStack {
                NavigationStack {
                    RecordPitchCoordinatorView(
                        onLanguageConfirmed: {},
                        onFinished: { audioData, langCode in
                            // Keep the cover open. Swap the
                            // recording pages for the analysing
                            // view (pulsing icon + spinner) and run
                            // the real analyzer on a background
                            // task. When it finishes we dismiss the
                            // cover and push ReviewSummary onto the
                            // main stack.
                            isAnalyzing = true
                            analyzer.languageCode = langCode
                            // ← fixes English-only bug

                            Task {
                                do {
                                    let result = try await analyzer.analyze(audioData: audioData)
                                    presentedRecording = false
                                    isAnalyzing = false
                                    onboardingViewModel.path.append(
                                        AppRoute.reviewSummary(result)
                                    )
                                } catch {
                                    print("Analysis failed: \(error)")
                                    presentedRecording = false
                                    isAnalyzing = false
                                }
                            }
                        },
                        onCancelled: {
                            presentedRecording = false
                        }
                    )
                }
                .toolbar(.hidden, for: .bottomBar)
                // Hide the recording pages while analysis is running
                // so only the analysing view is visible. SwiftUI
                // doesn't animate the swap-out by default, but the
                // analysing view itself has a pulsing icon and
                // spinner which give the user clear feedback.
                .opacity(isAnalyzing ? 0 : 1)
                .allowsHitTesting(!isAnalyzing)

                // Show the analysing view on top of the recording
                // pages once `isAnalyzing` is true. The view fades
                // the recording pages out (above) and the analysing
                // view fades in with its built-in pulse + spinner.
                if isAnalyzing {
                    AnalyzingRecordingView()
                        .transition(.opacity)
                }
            }
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

    /// Native bottom bar — like Apple Health / Apple Music.
    /// Layout:
    ///   - LEFT side (Home + History): two plain icon buttons, no
    ///     custom circles or capsules. They sit on the iOS liquid
    ///     glass material that the system draws behind the
    ///     bottom-bar slot, and the system applies the native
    ///     press / hover highlight on top automatically.
    ///   - RIGHT side (Mic): a single circular button (floating
    ///     action-button style) that stands out as the primary
    ///     action — also native, sitting on the same liquid glass.
    ///
    /// Both the tab icons and the primary action use the SAME
    /// `bottomBarButton(...)` helper so the bottom-bar code stays
    /// uniform. The only difference is the `isPrimary` flag, which
    /// turns the mic's glass treatment into a circle (so it
    /// stands out as the primary call-to-action) versus the tab
    /// icons' plain rectangle.
    private var bottomBarLeading: some View {
        HStack(spacing: 40) {
            bottomBarButton(
                systemImage: "house.fill",
                isActive: currentTab == .home
            ) {
                if currentTab != .home {
                    currentTab = .home
                    onboardingViewModel.path = NavigationPath()
                }
            }
            bottomBarButton(
                systemImage: "clock.arrow.circlepath",
                isActive: currentTab == .history
            ) {
                if currentTab != .history {
                    currentTab = .history
                    onboardingViewModel.path = NavigationPath()
                }
            }
        }
    }

    private var bottomBarTrailing: some View {
        bottomBarButton(
            systemImage: AppIcon.micIcon,
            isActive: false,
            isPrimary: true
        ) {
            presentedRecording = true
        }
    }

    /// Unified bottom-bar button.
    /// - `isPrimary == false` (default): plain native tab icon.
    ///   iOS draws the native press / hover highlight on top of
    ///   the bottom bar's liquid glass automatically.
    /// - `isPrimary == true`: same plain native icon but with a
    ///   circular hit-target (so the press highlight is a circle
    ///   instead of a rectangle). The mic icon is still rendered
    ///   on the iOS liquid glass material that the system draws
    ///   behind the bottom-bar slot — NO extra fill / glass circle
    ///   is added behind the icon.
    private func bottomBarButton(
        systemImage: String,
        isActive: Bool = false,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let icon = Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isActive ? Color.accentColor : .primary)
            .frame(width: 44, height: 44)
            .contentShape(isPrimary ? AnyShape(Circle()) : AnyShape(Rectangle()))

        return Button(action: action) { icon }
            .buttonStyle(.plain)
    }
}

#Preview {
    AppRootView()
}
