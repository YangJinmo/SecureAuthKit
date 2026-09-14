import SwiftUI

@main
struct SecureAuthKitDemoApp: App {
    @StateObject private var viewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
