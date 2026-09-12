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
        }
        .padding()
        .task {
            await viewModel.unlockWithBiometrics()
        }
    }
}
