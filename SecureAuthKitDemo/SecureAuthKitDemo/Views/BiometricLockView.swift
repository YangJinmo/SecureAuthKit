import SwiftUI

struct BiometricLockView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
            Text("Unlock to continue")
                .font(.headline)
            Button("Unlock") {
                Task { await viewModel.unlockWithBiometrics() }
            }
            .buttonStyle(.borderedProminent)
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            // Escape hatch: without this, a device that can no longer authenticate (biometrics
            // unenrolled, passcode removed, or locked out) leaves this screen with no way forward.
            Button("Sign Out") {
                Task { await viewModel.signOut() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            await viewModel.unlockWithBiometrics()
        }
    }
}
