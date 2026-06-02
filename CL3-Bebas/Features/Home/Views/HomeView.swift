import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}
