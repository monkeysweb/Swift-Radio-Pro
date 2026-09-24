import SwiftUI
import UserNotifications

private let rowColors: [Color] = [.pcYellow, .pcCyan, .pcCoral, .pcPurple, .pcGreen]

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddFriend = false
    @State private var pushDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pcCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if let sender = appState.lastReceivedFrom {
                            PCCard(color: .pcYellow) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("🏴 Pirate Cat from \(sender)")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(Color.pcInk)
                                        Text("Tap their name below to send it back.")
                                            .font(.footnote)
                                            .foregroundStyle(Color.pcInk.opacity(0.7))
                                    }
                                    Spacer()
                                    Button {
                                        appState.lastReceivedFrom = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.pcInk.opacity(0.6))
                                    }
                                }
                            }
                        }

                        if pushDenied {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                PCCard(color: .pcCoral) {
                                    Text("Notifications are off — tap to turn them on in Settings so you can receive Pirate Cats.")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.pcInk)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if appState.friends.isEmpty {
                            PCCard(color: .pcCyan) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No one added yet")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(Color.pcInk)
                                    Text("Tap + to find someone by their exact display name.")
                                        .font(.footnote)
                                        .foregroundStyle(Color.pcInk.opacity(0.75))
                                }
                            }
                        } else {
                            ForEach(Array(appState.friends.enumerated()), id: \.element.id) { index, friend in
                                Button {
                                    Task { await appState.sendYo(to: friend) }
                                } label: {
                                    PCCard(color: rowColors[index % rowColors.count]) {
                                        HStack {
                                            Text(friend.displayName)
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(Color.pcInk)
                                            Spacer()
                                            if appState.sendingFriendIds.contains(friend.id) {
                                                ProgressView().tint(Color.pcInk)
                                            } else {
                                                Text("Tap to send")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(Color.pcInk.opacity(0.6))
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(appState.sendingFriendIds.contains(friend.id))
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await appState.refreshFriends() }
            }
            .navigationTitle("Pirate Cat")
            .toolbarBackground(Color.pcCream, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddFriend = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.pcInk)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign out") { appState.signOut() }
                        .foregroundStyle(Color.pcInk)
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
