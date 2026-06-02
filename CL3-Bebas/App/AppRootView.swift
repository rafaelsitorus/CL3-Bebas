import SwiftUI

struct AppRootView: View {
    var body: some View {
        HomeView(viewModel: HomeViewModel())
    }
}

#Preview {
    AppRootView()
}
