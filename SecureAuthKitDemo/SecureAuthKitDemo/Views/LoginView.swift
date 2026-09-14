import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var username = "demo"
    @State private var password = "password123"
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign In") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                Section {
                    Text("Demo credentials: demo / password123")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        isSigningIn = true
                        await viewModel.signIn(username: username, password: password)
                        isSigningIn = false
                    }
                } label: {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(isSigningIn)
            }
            .navigationTitle("SecureAuthKit Demo")
            .alert("Sign In Failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
