import SwiftUI

@main
struct PirateCatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    appDelegate.appState = appState
                    await appState.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isSignedIn {
                HomeView()
            } else {
                AuthView()
            }
        }
        .animation(.default, value: appState.isSignedIn)
    }
}
