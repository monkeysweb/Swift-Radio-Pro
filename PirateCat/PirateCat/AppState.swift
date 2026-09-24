import Foundation
import UIKit
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: PCUser?
    @Published var friends: [PCFriend] = []
    @Published var authError: String?
    @Published var isLoading = false

    /// Set when a push notification is tapped, so the UI can surface who
    /// sent it and offer a one-tap "send it back".
    @Published var lastReceivedFrom: String?

    /// Friend ids currently mid-send, so a duplicate tap on the same row is
    /// ignored instead of firing a second network request.
    @Published var sendingFriendIds: Set<String> = []
    @Published var toast: String?

    private var pendingDeviceToken: String?

    var isSignedIn: Bool { currentUser != nil }

    func bootstrap() async {
        guard let token = KeychainStore.loadToken() else { return }
        await APIClient.shared.setToken(token)
        await refreshFriends()
    }

    func signup(displayName: String, password: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.signup(displayName: displayName, password: password)
            try await finishSignIn(response)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signin(displayName: String, password: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.signin(displayName: displayName, password: password)
            try await finishSignIn(response)
        } catch {
            authError = error.localizedDescription
        }
    }

    private func finishSignIn(_ response: PCAuthResponse) async throws {
        KeychainStore.saveToken(response.token)
        await APIClient.shared.setToken(response.token)
        currentUser = response.user
        await refreshFriends()
        registerForPushIfNeeded()
        if let pendingDeviceToken {
            await sendDeviceToken(pendingDeviceToken)
        }
    }

    func signOut() {
        KeychainStore.clearToken()
        Task { await APIClient.shared.setToken(nil) }
        currentUser = nil
        friends = []
    }

    func refreshFriends() async {
        do {
            friends = try await APIClient.shared.fetchFriends()
        } catch APIError.unauthorized {
            signOut()
        } catch {
            toast = error.localizedDescription
        }
    }

    func addFriend(displayName: String) async -> Bool {
        do {
            _ = try await APIClient.shared.addFriend(displayName: displayName)
            await refreshFriends()
            return true
        } catch {
            toast = error.localizedDescription
            return false
        }
    }

    /// Tapping a name sends "Pirate Cat" immediately. Guards against
    /// duplicate taps (a second tap while one is in flight is a no-op) and
    /// surfaces offline/rate-limit/unavailable-token failures without
    /// crashing or leaving the UI stuck.
    func sendYo(to friend: PCFriend) async {
        guard !sendingFriendIds.contains(friend.id) else { return }
        sendingFriendIds.insert(friend.id)
        defer { sendingFriendIds.remove(friend.id) }
        do {
            let delivered = try await APIClient.shared.sendYo(friendId: friend.id)
            toast = delivered ? "Sent Pirate Cat to \(friend.displayName)" : "Sent — \(friend.displayName) isn't reachable for push right now"
        } catch APIError.unauthorized {
            signOut()
        } catch {
            toast = error.localizedDescription
        }
    }

    // MARK: Push notifications

    func registerForPushIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted == true {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .authorized, .provisional, .ephemeral:
                UIApplication.shared.registerForRemoteNotifications()
            case .denied:
                break // Handled by a banner in HomeView, not forced here.
            @unknown default:
                break
            }
        }
    }

    func didReceiveDeviceToken(_ token: String) {
        guard isSignedIn else {
            pendingDeviceToken = token
            return
        }
        Task { await sendDeviceToken(token) }
    }

    private func sendDeviceToken(_ token: String) async {
        #if targetEnvironment(simulator)
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            try await APIClient.shared.registerDevice(token: token, environment: environment)
            pendingDeviceToken = nil
        } catch {
            // Registration is retried on next launch/foreground; not fatal.
        }
    }

    func didTapNotification(fromDisplayName: String) {
        lastReceivedFrom = fromDisplayName
    }
}
