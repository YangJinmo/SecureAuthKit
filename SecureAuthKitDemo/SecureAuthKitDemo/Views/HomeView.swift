import SwiftUI
import SecureAuthKit

struct HomeView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let token = viewModel.currentToken {
                    Text("Signed in as \(token.subject)")
                        .font(.headline)
                    Text("Expires at \(token.expiresAt.formatted(date: .omitted, time: .standard))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Refresh Token") {
                    Task { await viewModel.refreshToken() }
                }
                .buttonStyle(.bordered)
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                .buttonStyle(.bordered)
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}
