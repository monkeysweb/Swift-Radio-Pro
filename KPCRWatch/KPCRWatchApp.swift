import SwiftUI

@main
struct KPCRWatchApp: App {
    @StateObject private var player = WatchPlayer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                // Tapping the complication opens kpcrradio://play.
                .onOpenURL { url in
                    if url.host == "play" { player.play() }
                }
        }
    }
}

enum KPCRWatchStyle {
    static let yellow = Color(red: 1.0, green: 0.82, blue: 0.32)
    static let cyan = Color(red: 0.37, green: 0.87, blue: 0.88)
    static let coral = Color(red: 1.0, green: 0.44, blue: 0.40)
}

struct ContentView: View {
    @EnvironmentObject private var player: WatchPlayer

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .padding(1)
                        .background(KPCRWatchStyle.cyan, in: Circle())
                        .frame(width: 30, height: 30)
                    Text("KPCR")
                        .font(.system(.headline, design: .rounded).weight(.black))
                    Spacer()
                    if player.isPlaying {
                        Text("LIVE")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(KPCRWatchStyle.coral, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.nowPlaying.headline)
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .lineLimit(2)
                    if let detail = player.nowPlaying.detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: player.togglePlayback) {
                    ZStack {
                        Circle().fill(KPCRWatchStyle.yellow)
                        if player.isStarting {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(width: 76, height: 76)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying || player.isStarting ? "Stop Pirate Cat Radio" : "Play Pirate Cat Radio")

                if let message = player.message {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(KPCRWatchStyle.yellow)
                }

                if player.phoneReachable {
                    Button(action: player.togglePhonePlayback) {
                        Label(player.phoneIsPlaying ? "Stop on iPhone" : "Play on iPhone", systemImage: "iphone")
                            .font(.footnote.weight(.semibold))
                    }
                    .tint(KPCRWatchStyle.cyan)
                }
            }
            .padding(.horizontal, 4)
        }
        .task {
            while !Task.isCancelled {
                await player.refreshNowPlaying()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}
