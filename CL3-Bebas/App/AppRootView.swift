import SwiftUI
struct AppRootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        NavigationStack {
            if onboardingComplete {
                HomeView()
            } else {
                OnboardingCoordinatorView {
                    onboardingComplete = true
                }
            }
        }
    }
}

#Preview {
    AppRootView()
}
