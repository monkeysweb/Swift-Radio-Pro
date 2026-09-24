import SwiftUI

struct AddFriendView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Their exact display name") {
                    TextField("Display name", text: $displayName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add someone")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task {
                                isSubmitting = true
                                let success = await appState.addFriend(displayName: displayName)
                                isSubmitting = false
                                if success { dismiss() }
                            }
                        }
                        .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
