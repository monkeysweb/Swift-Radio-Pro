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
        ZStack {
            Color.pcCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image("CatEyesMark")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96)
                            .foregroundStyle(Color.pcInk)
                        Text("PIRATE CAT")
                            .font(.system(.largeTitle, design: .rounded).weight(.black))
                            .foregroundStyle(Color.pcInk)
                        Text("Tap a name. They get a Pirate Cat.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.pcInk.opacity(0.65))
                    }
                    .padding(.top, 48)

                    PCCard(color: isSigningUp ? .pcYellow : .pcPurple) {
                        VStack(spacing: 14) {
                            Text(isSigningUp ? "CREATE ACCOUNT" : "SIGN IN")
                                .font(.caption.weight(.bold))
                                .kerning(1)
                                .foregroundStyle(Color.pcInk.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("Display name", text: $displayName)
                                .textFieldStyle(PCTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)

                            SecureField("Password", text: $password)
                                .textFieldStyle(PCTextFieldStyle())
                                .textContentType(isSigningUp ? .newPassword : .password)

                            if let authError = appState.authError {
                                Text(authError)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.pcInk)
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
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
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSigningUp ? "Create account" : "Sign in")
                                }
                            }
                            .buttonStyle(PCPrimaryButtonStyle())
                            .disabled(!canSubmit)
                        }
                    }

                    Button(isSigningUp ? "Already have an account? Sign in" : "New here? Create an account") {
                        isSigningUp.toggle()
                        appState.authError = nil
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.pcInk)
                    .underline()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
