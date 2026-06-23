import SwiftUI
import SwiftData

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
        imageName: "PT1",
        title: "PITCHING TIPS",
        status: "How To Control Your Speaking Pace Under Pressure", description: """
        Speaking under pressure often causes people to speed up without realizing it. When this happens, listeners may struggle to follow your message, and important points can lose their impact.

        One effective way to manage your pace is to use intentional pauses. Brief pauses between ideas give you time to think while allowing listeners to absorb what you have said. Focusing on key messages rather than rushing through every sentence can also help maintain a steady rhythm.

        Before an important presentation, practice speaking slightly slower than feels natural. During the presentation, take a breath before introducing a new idea and pause after delivering an important point. These small adjustments can make your speech sound more confident, clear, and engaging, even in high-pressure situations.
        """)
    
    static let speakingHabits = Article(imageName: "PT2", title: "PITCHING TIPS", status: "Common Speaking Habits That Weaken a Pitch", description: """
        Many speakers unknowingly develop habits that reduce the effectiveness of their pitch. Speaking too quickly, relying on filler words, using a monotone voice, or pronouncing words unclearly can make it harder for listeners to understand and stay engaged with the message.
        
        These habits often become more noticeable under pressure. When presenters are nervous or focused on remembering their content, they may rush through ideas, repeat unnecessary words, or speak with limited vocal variation. As a result, important points may receive less attention than they deserve.
        
        Improving delivery starts with awareness. Reviewing recordings can help identify recurring speaking habits and highlight areas for improvement. By practicing clearer articulation, maintaining an effective pace, and using intentional vocal variation, speakers can deliver their message with greater confidence and impact.
        """)
    
    static let intonationRole = Article(imageName: "CF1", title: "COMMUNICATION FUNDAMENTAL", status: "The Role of Intonation in Effective Speaking", description: """
        Intonation refers to the rise and fall of your voice while speaking. It helps communicate emphasis, emotion, and meaning beyond the words themselves. Without sufficient vocal variation, a message may sound flat and become less engaging for listeners.

        Effective speakers use intonation to highlight important ideas and guide listeners through their message. Changes in pitch can signal excitement, confidence, or importance, making it easier for audiences to follow key points and stay attentive throughout a presentation.

        Improving intonation starts with becoming more aware of your vocal delivery. Try emphasizing important words, varying your pitch between ideas, and listening to recordings of your speech. Small adjustments in vocal variation can make your message sound more engaging, expressive, and memorable.
        """)
}

struct AppRootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    /// Shared store of recordings. Injected as an environment object
    /// so any view (History, recording flow) can read or write.
    ///
    /// The store is initialised lazily on first appearance, once the
    /// SwiftUI environment is up, so we can pass it the shared
    /// `ModelContext` from `\.modelContext`. (The container is created
    /// in `CL3_BebasApp` and made available to the whole view
    /// hierarchy via `.modelContainer(...)`.)
    @StateObject private var historyStore = HistoryStore()
    @Environment(\.modelContext) private var modelContext

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

    // MARK: - Body

    var body: some View {
        // Single NavigationStack bound to the shared path. The root
        // is decided by `currentTab`, so Home and History are peer
        // top-level destinations. Both share the same native path,
        // so any pushed detail (article, review-summary, etc.) is
        // popped by the same back chevron.
        //
        // NB: the page background is applied to `rootContent` (the
        // inner view) instead of the `NavigationStack` itself.
        // Attaching `.background` to the `NavigationStack` is
        // unreliable because each child destination declares its
        // own background and SwiftUI draws the NavigationStack's
        // chrome on top of any background set on the stack itself.
        // Putting `.background` on the content view guarantees the
        // tint shows behind every screen — root, pushed, and
        // back-swiped — and is the documented SwiftUI best practice.
        NavigationStack(path: $onboardingViewModel.path) {
            rootContent
                // Single source of truth for the page background. We
                // reuse the design-system `Color.lightGrayBC` token
                // (`#F9F9F9`) so the tint matches the rest of the
                // app. `.ignoresSafeArea()` makes it extend under the
                // navigation chrome and the bottom bar so the tint
                // fills the whole screen.
                .background(Color.lightGrayBC.ignoresSafeArea())
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
                        onFinished: { audioData, langCode, recordingTitle in
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

                                    // Persist the completed recording
                                    // to SwiftData BEFORE dismissing
                                    // the cover so the History list
                                    // already shows the new row by
                                    // the time the user sees
                                    // ReviewSummary. The
                                    // `ModelContext` is injected
                                    // lazily via `\.modelContext`
                                    // so we wire it into the
                                    // shared `HistoryStore` here.
                                    historyStore.configure(modelContext: modelContext)
                                    let saved = historyStore.save(
                                        result: result,
                                        languageCode: langCode,
                                        title: recordingTitle
                                    )
                                    if let saved {
                                        print("✅ Saved recording to SwiftData: \(saved.title)")
                                    }

                                    presentedRecording = false
                                    isAnalyzing = false

                                    // Stamp the freshly-saved model's
                                    // id onto the `AnalysisResult` we
                                    // push onto the navigation stack.
                                    // `ReviewSummaryView` uses
                                    // `result.id` to look the
                                    // `RecordingHistoryModel` back up
                                    // from SwiftData, so a title edit
                                    // on this first-launch screen
                                    // persists to the same row the
                                    // user will see when they later
                                    // open the History list.
                                    var resultWithId = result
                                    resultWithId.id = saved?.id
                                    onboardingViewModel.path.append(
                                        AppRoute.reviewSummary(resultWithId)
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
        HStack(spacing: 10) {
            bottomBarButton(
                systemImage: "house.fill",
                isActive: currentTab == .home
            )
            {
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
        .padding(.horizontal, 10)
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
