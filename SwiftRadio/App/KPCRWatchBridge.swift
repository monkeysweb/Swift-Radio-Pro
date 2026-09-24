import FRadioPlayer
import Foundation
import WatchConnectivity

/// Lets the Apple Watch app start and stop the live stream on this iPhone.
final class KPCRWatchBridge: NSObject, WCSessionDelegate {
    static let shared = KPCRWatchBridge()
    private static let liveStreamURL = URL(string: "https://kpcrfm.radioca.st/stream.mp3")!

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            let player = FRadioPlayer.shared
            switch message["command"] as? String {
            case "play":
                // Always the live stream, even if a podcast episode was loaded last.
                let stations = StationsManager.shared
                if stations.currentStation == nil { stations.set(station: stations.stations.first) }
                let live = stations.currentStation.flatMap { URL(string: $0.streamURL) } ?? Self.liveStreamURL
                if player.radioURL != live { player.radioURL = live }
                player.play()
                replyHandler(["playing": true])
            case "stop":
                player.stop()
                replyHandler(["playing": false])
            default:
                replyHandler(["playing": player.isPlaying])
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
