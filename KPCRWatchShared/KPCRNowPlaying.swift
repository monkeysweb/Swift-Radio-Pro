import Foundation

enum KPCRStation {
    static let streamURL = URL(string: "https://kpcrfm.radioca.st/stream.mp3")!
    static let nowPlayingURL = URL(string: "https://kpcr.org/api/now-playing")!
    /// Opened by the complication; the watch app starts the stream when it sees it.
    static let playURL = URL(string: "kpcrradio://play")!
}

struct KPCRNowPlaying: Codable, Equatable {
    var show: String?
    var track: String?
    var artist: String?

    static let placeholder = KPCRNowPlaying(show: "Pirate Cat Radio", track: nil, artist: nil)

    var headline: String { clean(show) ?? "Pirate Cat Radio" }

    /// The song line, or nil when the station only reports the show itself.
    var detail: String? {
        guard let track = clean(track), track != clean(show) else { return nil }
        if let artist = clean(artist) { return "\(track) · \(artist)" }
        return track
    }

    static func fetch() async -> KPCRNowPlaying? {
        var request = URLRequest(url: KPCRStation.nowPlayingURL)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(KPCRNowPlaying.self, from: data)
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
