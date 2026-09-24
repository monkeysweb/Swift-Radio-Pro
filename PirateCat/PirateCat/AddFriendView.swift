import SwiftUI

struct AddFriendView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pcCream.ignoresSafeArea()
                VStack(spacing: 16) {
                    PCCard(color: .pcCyan) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("THEIR EXACT DISPLAY NAME")
                                .font(.caption.weight(.bold))
                                .kerning(1)
                                .foregroundStyle(Color.pcInk.opacity(0.7))
                            TextField("Display name", text: $displayName)
                                .textFieldStyle(PCTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    Button {
                        Task {
                            isSubmitting = true
                            let success = await appState.addFriend(displayName: displayName)
                            isSubmitting = false
                            if success { dismiss() }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Add")
                        }
                    }
                    .buttonStyle(PCPrimaryButtonStyle())
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Add someone")
            .toolbarBackground(Color.pcCream, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pcInk)
                }
            }
        }
    }
}
