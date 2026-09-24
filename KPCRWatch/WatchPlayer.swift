import AVFoundation
import Foundation
import WatchConnectivity
import WidgetKit

/// Streams KPCR on the watch (to AirPods or other Bluetooth audio), or asks
/// the paired iPhone to play it when the phone is nearby.
@MainActor
final class WatchPlayer: NSObject, ObservableObject {
    static let shared = WatchPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var isStarting = false
    @Published private(set) var phoneReachable = false
    @Published private(set) var phoneIsPlaying = false
    @Published private(set) var nowPlaying = KPCRNowPlaying.placeholder
    @Published var message: String?

    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func togglePlayback() {
        isPlaying || isStarting ? stop() : play()
    }

    func play() {
        guard !isPlaying, !isStarting else { return }
        message = nil
        isStarting = true
        let session = AVAudioSession.sharedInstance()
        do {
            // Long-form audio is what lets watchOS stream to Bluetooth headphones
            // and keep playing with the screen off.
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            fail("Couldn't set up audio on this watch.")
            return
        }
        // watchOS shows its own headphone picker here when none are connected.
        session.activate(options: []) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                guard success else {
                    self.fail(self.phoneReachable
                        ? "Connect headphones to listen on your watch, or play it on your iPhone."
                        : "Connect AirPods or Bluetooth headphones to listen on your watch.")
                    return
                }
                self.startStream()
            }
        }
    }

    func stop() {
        statusObservation = nil
        player?.pause()
        player = nil
        isPlaying = false
        isStarting = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func togglePhonePlayback() {
        guard WCSession.default.isReachable else {
            message = "Open KPCR on your iPhone, then try again."
            return
        }
        let command = phoneIsPlaying ? "stop" : "play"
        if command == "play" { stop() }
        WCSession.default.sendMessage(["command": command], replyHandler: { reply in
            let playing = reply["playing"] as? Bool ?? (command == "play")
            Task { @MainActor in self.phoneIsPlaying = playing }
        }, errorHandler: { _ in
            Task { @MainActor in self.message = "Couldn't reach your iPhone." }
        })
    }

    func refreshNowPlaying() async {
        guard let latest = await KPCRNowPlaying.fetch() else { return }
        if latest != nowPlaying {
            nowPlaying = latest
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func startStream() {
        let item = AVPlayerItem(url: KPCRStation.streamURL)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .readyToPlay {
                    self.isStarting = false
                    self.isPlaying = true
                } else if item.status == .failed {
                    self.stop()
                    self.message = "The stream didn't load. Check your connection."
                }
            }
        }
        self.player = player
        player.play()
    }

    private func fail(_ text: String) {
        isStarting = false
        isPlaying = false
        message = text
    }
}

extension WatchPlayer: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in self.phoneReachable = reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.phoneReachable = reachable }
    }
}
