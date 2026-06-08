import SwiftUI
struct AppRootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            
            // Replace ini yeh bang
            Text("Home Screen lu mana Raja Sitorus")
        } else {
            OnboardingCoordinatorView {
                onboardingComplete = true
            }
        }
    }
}

#Preview {
    AppRootView()
}
