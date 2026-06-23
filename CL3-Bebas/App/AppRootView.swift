import SwiftUI
import SwiftData

// MARK: - App Route

enum AppRoute: Hashable {
    case reviewSummary(AnalysisResult)
    case paceReview(AnalysisResult)
    case articulationReview(AnalysisResult)
    case intonationReview(AnalysisResult)
    case unclearWords([PronunciationIssue], URL?)
    case article(Article)
}

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


struct AppRootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    @StateObject private var historyStore = HistoryStore()
    @Environment(\.modelContext) private var modelContext
    @State private var presentedRecording: Bool = false
    @State private var currentTab: AppTab = .home
    @State private var isAnalyzing: Bool = false
    @State private var analyzer = SpeechAnalyzer()

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $onboardingViewModel.path) {
            rootContent
                .background(Color.lightGrayBC.ignoresSafeArea())
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .environmentObject(historyStore)
        .toolbar {
            if onboardingComplete && shouldShowBottomBar {
                ToolbarItemGroup(placement: .bottomBar) {
                    bottomBarLeading
                    Spacer(minLength: 0)
                    bottomBarTrailing
                }
            }
        }
        .toolbarBackground(.visible, for: .bottomBar)
        .fullScreenCover(isPresented: $presentedRecording) {

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
                

                            Task {
                                do {
                                    let result = try await analyzer.analyze(audioData: audioData)

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
                .opacity(isAnalyzing ? 0 : 1)
                .allowsHitTesting(!isAnalyzing)

        
                if isAnalyzing {
                    AnalyzingRecordingView()
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Root Content

    private var shouldShowBottomBar: Bool {
        onboardingViewModel.path.isEmpty
    }

    @ViewBuilder
    private var rootContent: some View {
        if !onboardingComplete {
            OnboardingCoordinatorView(viewModel: onboardingViewModel) {
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
