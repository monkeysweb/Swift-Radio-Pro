import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isSigningUp = false
    @State private var displayName = ""
    @State private var password = ""

    private var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 8 && !appState.isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("🏴‍☠️🐈")
                    .font(.system(size: 64))
                Text("Pirate Cat")
                    .font(.largeTitle.bold())
                Text("Tap a name. They get a Pirate Cat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    TextField("Display name", text: $displayName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(isSigningUp ? .newPassword : .password)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    if let authError = appState.authError {
                        Text(authError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            if isSigningUp {
                                await appState.signup(displayName: displayName, password: password)
                            } else {
                                await appState.signin(displayName: displayName, password: password)
                            }
                        }
                    } label: {
                        if appState.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(isSigningUp ? "Create account" : "Sign in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)

                    Button(isSigningUp ? "Already have an account? Sign in" : "New here? Create an account") {
                        isSigningUp.toggle()
                        appState.authError = nil
                    }
                    .font(.footnote)
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }
}
