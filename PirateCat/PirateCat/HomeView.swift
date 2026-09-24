import SwiftUI
import UserNotifications

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddFriend = false
    @State private var pushDenied = false

    var body: some View {
        NavigationStack {
            List {
                if let sender = appState.lastReceivedFrom {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Pirate Cat from \(sender)").font(.headline)
                                Text("Tap their name below to send it back.").font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Dismiss") { appState.lastReceivedFrom = nil }
                                .font(.footnote)
                        }
                    }
                }

                if pushDenied {
                    Section {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Notifications are off — turn them on in Settings to receive Pirate Cats.")
                                .font(.footnote)
                        }
                    }
                }

                Section {
                    if appState.friends.isEmpty {
                        Text("No one added yet. Tap + to find someone by their exact display name.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(appState.friends) { friend in
                        Button {
                            Task { await appState.sendYo(to: friend) }
                        } label: {
                            HStack {
                                Text(friend.displayName)
                                Spacer()
                                if appState.sendingFriendIds.contains(friend.id) {
                                    ProgressView()
                                } else {
                                    Image(systemName: "hand.tap")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(appState.sendingFriendIds.contains(friend.id))
                    }
                }
            }
            .refreshable { await appState.refreshFriends() }
            .navigationTitle("Pirate Cat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddFriend = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign out") { appState.signOut() }
                }
            }
            .sheet(isPresented: $showAddFriend) { AddFriendView() }
            .task { await checkPushPermission() }
            .alert("Pirate Cat", isPresented: .constant(appState.toast != nil), actions: {
                Button("OK") { appState.toast = nil }
            }, message: {
                Text(appState.toast ?? "")
            })
        }
    }

    private func checkPushPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushDenied = settings.authorizationStatus == .denied
    }
}
