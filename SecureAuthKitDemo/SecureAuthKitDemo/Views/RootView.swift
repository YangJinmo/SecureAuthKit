import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        switch viewModel.state {
        case .loggedOut:
            LoginView(viewModel: viewModel)
        case .lockedBiometric:
            BiometricLockView(viewModel: viewModel)
        case .authenticated:
            HomeView(viewModel: viewModel)
        }
    }
}
