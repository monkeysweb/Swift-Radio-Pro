

import UIKit
import SafariServices
import FRadioPlayer
import CoreImage

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var coordinator: MainCoordinator?
    
    private let audioService = AudioSetupService.shared
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // UI Setup
        setupUIAppearance()
        
        // Start the coordinator
        setupCoordinator(windowScene: windowScene)
    }
    
    private func setupUIAppearance() {
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().tintColor = Config.tintColor
        UINavigationBar.appearance().prefersLargeTitles = true
    }
    
    private func setupCoordinator(windowScene: UIWindowScene) {
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = KPCRTabBarController()
        window?.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        audioService.activateAudioSession()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        audioService.activateAudioSession()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        audioService.activateAudioSession()
    }
}

// MARK: - KPCR App Shell

private enum KPCRStyle {
    static let cyan = UIColor(red: 0.39, green: 0.87, blue: 0.88, alpha: 1)
    static let blue = UIColor(red: 0.13, green: 0.58, blue: 0.65, alpha: 1)
    static let green = UIColor(red: 0.25, green: 0.75, blue: 0.38, alpha: 1)
    static let coral = UIColor(red: 1.00, green: 0.43, blue: 0.40, alpha: 1)
    static let red = UIColor(red: 0.82, green: 0.24, blue: 0.13, alpha: 1)
    static let yellow = UIColor(red: 1.00, green: 0.82, blue: 0.32, alpha: 1)
    static let purple = UIColor(red: 0.78, green: 0.46, blue: 0.96, alpha: 1)
    static let cream = UIColor(red: 0.96, green: 0.95, blue: 0.84, alpha: 1)
    static let paper = UIColor(red: 1.00, green: 0.98, blue: 0.92, alpha: 1)
    static let ice = UIColor(red: 0.92, green: 0.98, blue: 0.99, alpha: 1)
    static let ink = UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)
    static let drawer = UIColor(red: 0.10, green: 0.18, blue: 0.20, alpha: 1)

    /// Same rotation the website's events calendar cycles through per tile
    /// (src/pages/events.astro's TILE_COLORS), mapped onto this app's palette.
    static let tileColors: [UIColor] = [coral, purple, yellow, green, blue, red, cyan]
    static func tileColor(_ index: Int) -> UIColor {
        tileColors[((index % tileColors.count) + tileColors.count) % tileColors.count]
    }

    static func rounded(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}

private enum KPCRSession {
    static let didChange = Notification.Name("kpcrSessionChanged")
    private static let tokenKey = "kpcr.mobile.token"
    private static let userKey = "kpcr.mobile.user"
    private static let avatarIndexKey = "kpcr.mobile.avatarIndex"

    static var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    static var currentUser: KPCRMobileUser? {
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
        return try? JSONDecoder().decode(KPCRMobileUser.self, from: data)
    }

    static var isLoggedIn: Bool {
        token != nil && currentUser != nil
    }

    static let hasUploadedAvatar = false

    static var avatarIndex: Int {
        if UserDefaults.standard.object(forKey: avatarIndexKey) == nil {
            UserDefaults.standard.set(Int.random(in: 0..<KPCRAvatarAssets.count), forKey: avatarIndexKey)
        }
        return UserDefaults.standard.integer(forKey: avatarIndexKey)
    }

    static func signIn(token: String, user: KPCRMobileUser, assignNewAvatar: Bool = false) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        if assignNewAvatar || UserDefaults.standard.object(forKey: avatarIndexKey) == nil {
            UserDefaults.standard.set(Int.random(in: 0..<KPCRAvatarAssets.count), forKey: avatarIndexKey)
        }
        Task { @MainActor in await KPCRFavoritesStore.shared.load() }
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func signOut() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        Task { @MainActor in KPCRFavoritesStore.shared.clear() }
        KPCRMembershipCache.clear()
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

/// Shared, reactive cache for the logged-in user's Join It profile photo.
///
/// KPCRBaseViewController's header is a stored property (`let header =
/// KPCRHeaderView()`), so it's built once at view-controller allocation —
/// often before login has actually happened or before the network/token is
/// ready. A one-shot fetch at that moment can silently fail and never
/// retries. Any part of the app that successfully fetches membership stores
/// it here and posts `.kpcrMembershipChanged`, so avatar UI elsewhere
/// (built earlier or later, doesn't matter) can pick it up whenever it's
/// actually available instead of depending on its own construction timing.
private enum KPCRMembershipCache {
    static let didChange = Notification.Name("kpcrMembershipChanged")
    private(set) static var profileImageURL: String?

    static func store(_ payload: KPCRMembershipPayload) {
        let urlString = payload.membership.profileImageURL ?? payload.membership.profileImageUrl
        guard urlString != profileImageURL else { return }
        profileImageURL = urlString
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func clear() {
        guard profileImageURL != nil else { return }
        profileImageURL = nil
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

private struct KPCRMobileUser: Codable {
    let id: String
    let email: String
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let createdAt: String?
}

private struct KPCRAuthResponse: Codable {
    let token: String
    let user: KPCRMobileUser
}

private struct KPCRFavoritesPayload: Codable {
    let shows: [KPCRFavoriteShow]
    let tracks: [KPCRFavoriteTrack]
}

private struct KPCRFavoriteShow: Codable {
    let key: String
    let item: KPCRShow
    let createdAt: String?
}

private struct KPCRFavoriteTrack: Codable {
    let key: String
    let item: KPCRTrack
    let createdAt: String?
}

private struct KPCRFavoriteDeleteResponse: Codable {
    let removed: Bool
}

private struct KPCRGenericOKResponse: Codable {
    let ok: Bool
}

private struct KPCRUserResponse: Codable {
    let user: KPCRMobileUser
}

private struct KPCRMembershipPayload: Codable {
    let membership: KPCRMembership
    let checkoutUrl: String?
}

private struct KPCRMembership: Codable {
    let joinitMembershipId: String?
    let cardNumber: String?
    let memberNumber: String?
    let qrCodeUrl: String?
    let memberName: String?
    let profileImageUrl: String?
    let profileImageURL: String?
    let email: String?
    let membershipTypeName: String?
    let membershipTypeId: String?
    let isSignalSociety: Bool?
    let status: Int?
    let statusLabel: String
    let expirationDate: String?
    let cardUrl: String?
    let walletUrl: String?
    let lastSyncedAt: String?
    let source: String?
    let lookup_mode: String?
}

private struct KPCRAPIErrorResponse: Codable {
    let error: String
}

private enum KPCRAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authRequired
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The KPCR backend URL is invalid."
        case .invalidResponse:
            return "The KPCR backend did not respond correctly."
        case .authRequired:
            return "Please sign in again."
        case .server(let message):
            return message
        }
    }
}

private enum KPCRAvatarAssets {
    static let names = [
        "kpcr-avatar-cyan",
        "kpcr-avatar-green",
        "kpcr-avatar-cream",
        "kpcr-avatar-lavender",
        "kpcr-avatar-black",
    ]

    static var count: Int { names.count }

    static func image(index: Int) -> UIImage? {
        UIImage(named: names[((index % names.count) + names.count) % names.count])
    }
}

private struct KPCRShow: Codable {
    let slug: String?
    let title: String
    let host: String
    let imageUrl: String?
    let day: String?
    let time: String
    let description: String?
    let podcastRss: String?
}

private struct KPCRTrack: Codable {
    let title: String
    let artist: String
    let imageUrl: String?
    let airedAt: String
}

private struct KPCRGiveaway: Codable {
    let slug: String?
    let title: String
    let artist: String?
    let venue: String?
    let city: String?
    let startDate: String?
    let imageUrl: String?
    let giveawayUrl: String?
    let description: String?
}

private struct KPCRHomePayload: Codable {
    let currentShow: KPCRShow?
    let recentlyPlayed: [KPCRTrack]
    let upNext: [KPCRShow]
}

private struct KPCRSchedulePayload: Codable {
    struct Day: Codable {
        let day: String
        let shows: [KPCRShow]
    }
    let days: [Day]
}

private struct KPCRGiveawaysPayload: Codable {
    let giveaways: [KPCRGiveaway]
}

private struct KPCRPodcastPayload: Codable {
    let episodes: [KPCRPodcastEpisode]
}

private struct KPCRPodcastEpisode: Codable {
    let title: String
    let pubDate: String?
    let description: String?
    let enclosure: String?
    let link: String?
    let image: String?
}

private struct KPCRMusicBrainzRecordingSearch: Decodable {
    let recordings: [KPCRMusicBrainzRecording]
}

private struct KPCRMusicBrainzRecording: Decodable {
    let releases: [KPCRMusicBrainzRelease]?
}

private struct KPCRMusicBrainzRelease: Decodable {
    let id: String
}

private struct KPCRITunesSearchResponse: Decodable {
    let results: [KPCRITunesTrack]
}

private struct KPCRITunesTrack: Decodable {
    let artworkUrl100: String?
}

private struct KPCRCentovaRecentTracksResponse: Decodable {
    let data: [KPCRCentovaRecentTracksData]
}

private enum KPCRCentovaRecentTracksData: Decodable {
    case tracks([KPCRCentovaTrack])
    case ignored

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let tracks = try? container.decode([KPCRCentovaTrack].self) {
            self = .tracks(tracks)
        } else {
            self = .ignored
        }
    }
}

private struct KPCRCentovaTrack: Decodable {
    let artist: String
    let title: String
    let localtime: String?
}

private extension Notification.Name {
    static let kpcrNowPlayingChanged = Notification.Name("kpcrNowPlayingChanged")
    static let kpcrFavoritesChanged = Notification.Name("kpcrFavoritesChanged")
}

@MainActor
private final class KPCRFavoritesStore {
    static let shared = KPCRFavoritesStore()
    private(set) var shows: [KPCRFavoriteShow] = []
    private(set) var tracks: [KPCRFavoriteTrack] = []
    private var isLoading = false

    var showKeys: Set<String> { Set(shows.map(\.key)) }
    var trackKeys: Set<String> { Set(tracks.map(\.key)) }

    func load() async {
        guard KPCRSession.isLoggedIn, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await KPCRAPI.fetchFavorites()
            shows = payload.shows
            tracks = payload.tracks
            notify()
        } catch {
            notify()
        }
    }

    func clear() {
        shows = []
        tracks = []
        notify()
    }

    func isFavorite(show: KPCRShow) -> Bool {
        showKeys.contains(Self.key(for: show))
    }

    func isFavorite(track: KPCRTrack) -> Bool {
        trackKeys.contains(Self.key(for: track))
    }

    func toggle(show: KPCRShow) async {
        guard KPCRSession.isLoggedIn else {
            showSignInRequiredMessage()
            return
        }
        let key = Self.key(for: show)
        do {
            if showKeys.contains(key) {
                _ = try await KPCRAPI.removeFavorite(type: "show", key: key)
                shows.removeAll { $0.key == key }
            } else {
                let payload = try await KPCRAPI.saveFavorite(type: "show", item: show)
                shows = payload.shows
                tracks = payload.tracks
            }
            notify()
        } catch {
            showToast("  Could not update favorites.  ")
        }
    }

    func toggle(track: KPCRTrack) async {
        guard KPCRSession.isLoggedIn else {
            showSignInRequiredMessage()
            return
        }
        let key = Self.key(for: track)
        do {
            if trackKeys.contains(key) {
                _ = try await KPCRAPI.removeFavorite(type: "track", key: key)
                tracks.removeAll { $0.key == key }
            } else {
                let payload = try await KPCRAPI.saveFavorite(type: "track", item: track)
                shows = payload.shows
                tracks = payload.tracks
            }
            notify()
        } catch {
            showToast("  Could not update favorites.  ")
        }
    }

    static func key(for show: KPCRShow) -> String {
        (show.slug ?? show.title).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func key(for track: KPCRTrack) -> String {
        [track.title, track.artist]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    private func notify() {
        NotificationCenter.default.post(name: .kpcrFavoritesChanged, object: self)
    }
}

@MainActor
private final class KPCRNowPlayingCenter: NSObject {
    static let shared = KPCRNowPlayingCenter()
    private let player = FRadioPlayer.shared
    private var artworkTasks: [String: Task<UIImage?, Never>] = [:]
    private var artworkCache: [String: UIImage] = [:]
    private var refreshTask: Task<Void, Never>?
    private(set) var recentTracks: [KPCRTrack] = []
    private(set) var currentShow: KPCRShow?
    private(set) var currentShowArtwork: UIImage?
    private(set) var currentArtwork: UIImage?
    private(set) var currentTitle: String?
    private(set) var currentArtist: String?

    private override init() {
        super.init()
        player.addObserver(self)
    }

    func start() {
        refreshFromPlayer()
    }

    func refreshFromPlayer() {
        // Only update from live stream metadata when we actually have a track —
        // the player reports nil metadata whenever it isn't actively connected
        // (app launch, after stop, buffering gaps), and that should never blank
        // out a good title/artist already set from the schedule or recent-tracks
        // poll. "Currently playing" must reflect the station, not local playback.
        guard let title = clean(player.currentMetadata?.trackName),
              let artist = clean(player.currentMetadata?.artistName) else { return }
        guard title != currentTitle || artist != currentArtist else { return }
        currentTitle = title
        currentArtist = artist
        currentArtwork = artwork(for: title, artist: artist)
        addRecent(title: title, artist: artist)
        scheduleArtworkFetch(title: title, artist: artist)
        notify()
    }

    func artwork(for title: String?, artist: String?) -> UIImage? {
        guard let title, let artist else { return nil }
        return artworkCache[cacheKey(title: title, artist: artist)]
    }

    var liveShowForDisplay: KPCRShow? {
        guard let currentShow, isCurrentShowActive(currentShow) else { return nil }
        return currentShow
    }

    var displayTitle: String? {
        liveShowForDisplay?.title ?? currentTitle
    }

    var displayArtist: String? {
        if let show = liveShowForDisplay {
            return "w/ \(show.host)"
        }
        return currentArtist
    }

    var displayArtwork: UIImage? {
        liveShowForDisplay == nil ? currentArtwork : currentShowArtwork
    }

    func setCurrentShow(_ show: KPCRShow?) async {
        guard let show, isCurrentShowActive(show) else {
            currentShow = nil
            currentShowArtwork = nil
            notify()
            return
        }
        let didChange = currentShow?.slug != show.slug
        currentShow = show
        if didChange {
            currentShowArtwork = nil
        }
        notify()
        if let image = show.imageUrl, let url = URL(string: image), currentShowArtwork == nil {
            currentShowArtwork = await NetworkService.fetchImage(from: url)
            notify()
        }
    }

    func fetchArtwork(for track: KPCRTrack) {
        guard track.imageUrl == nil else { return }
        scheduleArtworkFetch(title: track.title, artist: track.artist)
    }

    func playPodcastEpisode(_ episode: KPCRPodcastEpisode, show: KPCRShow) async {
        guard let enclosure = episode.enclosure, let url = URL(string: enclosure) else { return }
        player.radioURL = url
        player.play()
        currentTitle = episode.title
        currentArtist = show.title
        currentArtwork = nil
        if let image = episode.image ?? show.imageUrl, let imageURL = URL(string: image) {
            currentArtwork = await NetworkService.fetchImage(from: imageURL)
        }
        notify()
    }

    func refreshRecentTracksFromShoutcast() async {
        let tracks = await KPCRAPI.fetchRecentTracksFromShoutcast()
        await setRecentTracks(tracks)
    }

    func setRecentTracks(_ tracks: [KPCRTrack]) async {
        guard !tracks.isEmpty else { return }
        recentTracks = Array(tracks.prefix(10))
        if let current = recentTracks.first {
            currentTitle = current.title
            currentArtist = current.artist
            currentArtwork = artwork(for: current.title, artist: current.artist)
        }
        notify()
        await withTaskGroup(of: Void.self) { group in
            for track in recentTracks {
                group.addTask { await self.cacheArtwork(for: track) }
            }
        }
    }

    private func scheduleArtworkFetch(title: String, artist: String) {
        let key = cacheKey(title: title, artist: artist)
        guard artworkCache[key] == nil, artworkTasks[key] == nil else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.loadArtwork(title: title, artist: artist, key: key)
        }
    }

    private func cacheArtwork(for track: KPCRTrack) async {
        let key = cacheKey(title: track.title, artist: track.artist)
        if artworkCache[key] != nil { return }
        if let imageUrl = track.imageUrl, let url = URL(string: imageUrl), let image = await NetworkService.fetchImage(from: url) {
            artworkCache[key] = image
            if cacheKey(title: currentTitle, artist: currentArtist) == key {
                currentArtwork = image
            }
            notify()
            return
        }
        fetchArtwork(for: track)
    }

    private func loadArtwork(title: String, artist: String, key: String) async {
        let task = Task { await KPCRAPI.fetchArtwork(artist: artist, title: title) }
        artworkTasks[key] = task
        let image = await task.value
        artworkTasks[key] = nil
        guard let image else { return }
        artworkCache[key] = image
        if cacheKey(title: currentTitle, artist: currentArtist) == key {
            currentArtwork = image
        }
        notify()
    }

    private func addRecent(title: String, artist: String) {
        let key = cacheKey(title: title, artist: artist)
        recentTracks.removeAll { cacheKey(title: $0.title, artist: $0.artist) == key }
        recentTracks.insert(KPCRTrack(title: title, artist: artist, imageUrl: nil, airedAt: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)), at: 0)
        recentTracks = Array(recentTracks.prefix(10))
    }

    private func clean(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private func cacheKey(title: String?, artist: String?) -> String {
        [title, artist].compactMap { $0?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "|")
    }

    private func isCurrentShowActive(_ show: KPCRShow) -> Bool {
        guard let day = show.day, !day.isEmpty else { return true }
        let calendar = Calendar(identifier: .gregorian)
        var pacificCalendar = calendar
        pacificCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = pacificCalendar.timeZone
        dayFormatter.dateFormat = "EEEE"
        guard dayFormatter.string(from: Date()).caseInsensitiveCompare(day) == .orderedSame else { return false }

        let parts = show.time.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let start = timeDate(parts[0], calendar: pacificCalendar),
              var end = timeDate(parts[1], calendar: pacificCalendar) else {
            return true
        }
        if end <= start, let nextDay = pacificCalendar.date(byAdding: .day, value: 1, to: end) {
            end = nextDay
        }
        let now = Date()
        return now >= start && now < end
    }

    private func timeDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = value.contains(":") ? "h:mm a" : "h a"
        guard let time = formatter.date(from: value.uppercased()) else { return nil }
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var today = calendar.dateComponents([.year, .month, .day], from: Date())
        today.hour = timeParts.hour
        today.minute = timeParts.minute
        return calendar.date(from: today)
    }

    private func notify() {
        NotificationCenter.default.post(name: .kpcrNowPlayingChanged, object: self)
    }
}

extension KPCRNowPlayingCenter: FRadioPlayerObserver {
    nonisolated func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
        Task { @MainActor in KPCRNowPlayingCenter.shared.refreshFromPlayer() }
    }
}

private enum KPCRAPI {
    static let base = "https://kpcr.org"

    static func fetchHome() async -> KPCRHomePayload {
        await fetch("/api/mobile/home") ?? KPCRHomePayload(currentShow: nil, recentlyPlayed: [], upNext: [])
    }

    static func fetchRecentTracksFromShoutcast() async -> [KPCRTrack] {
        var components = URLComponents(string: "https://perseus.shoutca.st/external/rpc.php")
        components?.queryItems = [
            URLQueryItem(name: "m", value: "recenttracks.get"),
            URLQueryItem(name: "username", value: "kpcrfm"),
            URLQueryItem(name: "rid", value: "kpcrfm"),
            URLQueryItem(name: "charset", value: ""),
            URLQueryItem(name: "mountpoint", value: ""),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "callback", value: "kpcrRecentTracks"),
        ]
        guard let url = components?.url else { return [] }
        do {
            let (data, urlResponse) = try await URLSession.shared.data(from: url)
            guard let http = urlResponse as? HTTPURLResponse, 200...299 ~= http.statusCode,
                  let body = String(data: data, encoding: .utf8),
                  let json = unwrapJSONP(body) else {
                return []
            }
            let payload = try JSONDecoder().decode(KPCRCentovaRecentTracksResponse.self, from: Data(json.utf8))
            guard case let .tracks(items)? = payload.data.first else { return [] }
            return items.compactMap { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let artist = item.artist.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !artist.isEmpty else { return nil }
                return KPCRTrack(title: title, artist: artist, imageUrl: nil, airedAt: item.localtime ?? "")
            }
        } catch {
            return []
        }
    }

    static func fetchSchedule() async -> KPCRSchedulePayload {
        await fetch("/api/mobile/schedule") ?? sampleSchedule
    }

    static func fetchGiveaways() async -> KPCRGiveawaysPayload {
        await fetch("/api/mobile/giveaways") ?? sampleGiveaways
    }

    static func signIn(email: String, password: String) async throws -> KPCRAuthResponse {
        try await auth(path: "/api/mobile/auth/signin", body: [
            "email": email,
            "password": password,
        ])
    }

    static func signUp(email: String, username: String, password: String) async throws -> KPCRAuthResponse {
        try await auth(path: "/api/mobile/auth/signup", body: [
            "email": email,
            "username": username,
            "password": password,
        ])
    }

    static func fetchFavorites() async throws -> KPCRFavoritesPayload {
        try await authenticated(path: "/api/mobile/favorites", method: "GET", body: Optional<[String: String]>.none)
    }

    static func saveFavorite<T: Encodable>(type: String, item: T) async throws -> KPCRFavoritesPayload {
        try await authenticated(path: "/api/mobile/favorites", method: "POST", body: [
            "type": type,
            "item": jsonObject(item),
        ])
    }

    static func removeFavorite(type: String, key: String) async throws -> Bool {
        let response: KPCRFavoriteDeleteResponse = try await authenticated(path: "/api/mobile/favorites", method: "DELETE", body: [
            "type": type,
            "key": key,
        ])
        return response.removed
    }

    static func requestPasswordReset(email: String) async throws {
        let _: KPCRGenericOKResponse = try await jsonRequest(path: "/api/mobile/auth/request-password-reset", method: "POST", body: [
            "email": email,
        ])
    }

    static func changePassword(currentPassword: String, newPassword: String) async throws {
        let _: KPCRUserResponse = try await authenticated(path: "/api/mobile/auth/change-password", method: "POST", body: [
            "currentPassword": currentPassword,
            "newPassword": newPassword,
        ])
    }

    static func deleteAccount(password: String) async throws {
        let _: KPCRGenericOKResponse = try await authenticated(path: "/api/mobile/auth/delete-account", method: "POST", body: [
            "password": password,
        ])
    }

    static func fetchMembership() async throws -> KPCRMembershipPayload {
        try await authenticated(path: "/api/mobile/membership", method: "GET", body: Optional<[String: String]>.none)
    }

    static func fetchPodcast(feedUrl: String) async -> KPCRPodcastPayload {
        let encoded = feedUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? feedUrl
        return await fetch("/api/podcast?url=\(encoded)") ?? KPCRPodcastPayload(episodes: [])
    }

    static func fetchArtwork(artist: String, title: String) async -> UIImage? {
        if let appleArtwork = await fetchAppleMusicArtwork(artist: artist, title: title) {
            return appleArtwork
        }
        return await fetchMusicBrainzArtwork(artist: artist, title: title)
    }

    static func fetchAppleMusicArtwork(artist: String, title: String) async -> UIImage? {
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedArtist.isEmpty, !cleanedTitle.isEmpty else { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(cleanedArtist) \(cleanedTitle)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = components?.url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return nil }
            let search = try JSONDecoder().decode(KPCRITunesSearchResponse.self, from: data)
            guard let artwork = search.results.compactMap(\.artworkUrl100).first else { return nil }
            let largeArtwork = artwork
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "100x100-999", with: "600x600-999")
            guard let imageURL = URL(string: largeArtwork) else { return nil }
            return await NetworkService.fetchImage(from: imageURL)
        } catch {
            return nil
        }
    }

    static func fetchMusicBrainzArtwork(artist: String, title: String) async -> UIImage? {
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedArtist.isEmpty, !cleanedTitle.isEmpty else { return nil }

        var components = URLComponents(string: "https://musicbrainz.org/ws/2/recording")
        components?.queryItems = [
            URLQueryItem(name: "query", value: "artist:\"\(cleanedArtist)\" AND recording:\"\(cleanedTitle)\""),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("KPCRRadio/1.0 (https://kpcr.org)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return nil }
            let search = try JSONDecoder().decode(KPCRMusicBrainzRecordingSearch.self, from: data)
            guard let releaseID = search.recordings.compactMap({ $0.releases?.first?.id }).first,
                  let coverURL = URL(string: "https://coverartarchive.org/release/\(releaseID)/front-500") else {
                return nil
            }
            return await NetworkService.fetchImage(from: coverURL)
        } catch {
            return nil
        }
    }

    private static func fetch<T: Decodable>(_ path: String) async -> T? {
        guard let url = URL(string: base + path) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private static func auth(path: String, body: [String: String]) async throws -> KPCRAuthResponse {
        try await jsonRequest(path: path, method: "POST", body: body)
    }

    private static func jsonRequest<T: Decodable>(path: String, method: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: base + path) else { throw KPCRAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KPCRAPIError.invalidResponse }
        guard 200...299 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(KPCRAPIErrorResponse.self, from: data).error) ?? "Sign in failed."
            throw KPCRAPIError.server(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func authenticated<T: Decodable, Body>(path: String, method: String, body: Body?) async throws -> T {
        guard let url = URL(string: base + path) else { throw KPCRAPIError.invalidURL }
        guard let token = KPCRSession.token else { throw KPCRAPIError.server("Sign in required.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KPCRAPIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw KPCRAPIError.authRequired
        }
        guard 200...299 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(KPCRAPIErrorResponse.self, from: data).error) ?? "The KPCR backend did not respond correctly."
            throw KPCRAPIError.server(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func jsonObject<T: Encodable>(_ value: T) -> Any {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return [:]
        }
        return object
    }

    private static func unwrapJSONP(_ body: String) -> String? {
        guard let open = body.firstIndex(of: "("), let close = body.lastIndex(of: ")"), open < close else {
            return nil
        }
        return String(body[body.index(after: open)..<close])
    }

    static let sampleShows = [
        KPCRShow(slug: "ocean-of-tears", title: "Ocean of Tears", host: "Captain Scabheart", imageUrl: nil, day: "Tuesday", time: "10:00 AM - 11:00 AM", description: "Sea-swept sounds from the Central Coast.", podcastRss: nil),
        KPCRShow(slug: "beat-salad", title: "Beat Salad", host: "Mason O'Brien", imageUrl: nil, day: "Tuesday", time: "11:00 AM - 12:00 PM", description: "Fresh local rhythm and deep cuts.", podcastRss: nil),
        KPCRShow(slug: "blue-hour", title: "The Blue Hour", host: "Blue Corvidae", imageUrl: nil, day: "Tuesday", time: "12:00 PM - 2:00 PM", description: "Afternoon radio for wandering ears.", podcastRss: nil),
        KPCRShow(slug: "private-pdx", title: "Your Own Private PDX", host: "DJ Squiffy", imageUrl: nil, day: "Tuesday", time: "3:00 PM - 5:00 PM", description: "Weekly indie music and conversation.", podcastRss: nil),
        KPCRShow(slug: "porch-hang", title: "Porch Hang", host: "Ash Allen", imageUrl: nil, day: "Tuesday", time: "5:00 PM - 6:00 PM", description: "Easygoing songs and neighborhood energy.", podcastRss: nil),
    ]

    static let sampleTracks = [
        KPCRTrack(title: "Do Your Math", artist: "Mr. Vale's Math Class", imageUrl: nil, airedAt: "9:24 AM"),
        KPCRTrack(title: "Under the Peach Tree", artist: "Kat White", imageUrl: nil, airedAt: "9:21 AM"),
        KPCRTrack(title: "Kid Again", artist: "FLOOR IS LAVA", imageUrl: nil, airedAt: "9:16 AM"),
        KPCRTrack(title: "Paradise Tax", artist: "Paradise Tax", imageUrl: nil, airedAt: "9:11 AM"),
        KPCRTrack(title: "No Romeo", artist: "Samie Jo", imageUrl: nil, airedAt: "9:08 AM"),
    ]

    static let sampleHome = KPCRHomePayload(currentShow: sampleShows.first, recentlyPlayed: sampleTracks, upNext: Array(sampleShows.dropFirst()))
    static let sampleSchedule = KPCRSchedulePayload(days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].map { day in
        KPCRSchedulePayload.Day(day: day, shows: day == "Tuesday" ? sampleShows : Array(sampleShows.prefix(3)))
    })
    static let sampleGiveaways = KPCRGiveawaysPayload(giveaways: [
        KPCRGiveaway(slug: "felton-show", title: "Felton Music Hall Giveaway", artist: "KPCR Concerts+", venue: "Felton Music Hall", city: "Felton", startDate: nil, imageUrl: nil, giveawayUrl: "https://forms.gle/GwYXvzUwyZ24LDx28", description: "Signal Society members get double entries."),
        KPCRGiveaway(slug: "catalyst-show", title: "The Catalyst Ticket Giveaway", artist: "KPCR Concerts+", venue: "The Catalyst", city: "Santa Cruz", startDate: nil, imageUrl: nil, giveawayUrl: "https://forms.gle/GwYXvzUwyZ24LDx28", description: "Enter to win tickets from KPCR.")
    ])
}

private final class KPCRTabBarController: UITabBarController {
    private let miniPlayer = KPCRMiniPlayerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabs()
        configureMiniPlayer()
        configureAudio()
    }

    private func configureTabs() {
        let home = KPCRHomeViewController()
        let schedule = KPCRScheduleViewController()
        let win = KPCRWinViewController()
        let chat = KPCRComingSoonViewController(titleText: "Chat", message: "KPCR chat is coming soon.")
        let my = KPCRMyPCRViewController()

        viewControllers = [
            nav(home, "Home", "house"),
            nav(schedule, "Schedule", "calendar"),
            nav(win, "Win", "ticket"),
            nav(chat, "Chat", "bubble.left"),
            nav(my, "My KPCR", "antenna.radiowaves.left.and.right"),
        ]

        tabBar.tintColor = .white
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.72)
        tabBar.barTintColor = KPCRStyle.green
        tabBar.backgroundColor = KPCRStyle.green
        tabBar.isTranslucent = false
    }

    private func nav(_ root: UIViewController, _ title: String, _ icon: String) -> UINavigationController {
        root.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), selectedImage: UIImage(systemName: icon + ".fill"))
        let nav = UINavigationController(rootViewController: root)
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }

    private func configureMiniPlayer() {
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(miniPlayer)
        NSLayoutConstraint.activate([
            miniPlayer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayer.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            miniPlayer.heightAnchor.constraint(equalToConstant: 76),
        ])
    }

    private func configureAudio() {
        Task { @MainActor in
            try? await StationsManager.shared.fetch()
            if StationsManager.shared.currentStation == nil {
                StationsManager.shared.set(station: StationsManager.shared.stations.first)
            }
            KPCRNowPlayingCenter.shared.start()
            miniPlayer.refresh()
        }
    }
}

private class KPCRBaseViewController: UIViewController {
    let scrollView = UIScrollView()
    let contentStack = UIStackView()
    private let header = KPCRHeaderView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KPCRStyle.cream
        buildChrome()
    }

    func buildChrome() {
        header.menuAction = { [weak self] in self?.presentDrawer() }
        header.avatarAction = { [weak self] in self?.presentProfile() }
        header.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        // The tab bar's mini player floats above the tab bar as a plain
        // overlay, not a container chrome element, so it isn't reflected in
        // the system safe area. Reserve room for it directly so scrolled
        // content always clears it instead of settling underneath it.
        scrollView.contentInset.bottom = 76
        scrollView.verticalScrollIndicatorInsets.bottom = 76
        contentStack.axis = .vertical
        contentStack.spacing = 22
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 156),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = KPCRStyle.rounded(24, weight: .black)
        label.textColor = KPCRStyle.ink
        return label
    }

    func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        present(SFSafariViewController(url: kpcrEmbeddedURL(url)), animated: true)
    }

    /// Marks kpcr.org links as opened from inside the app (`?app=1`) so the
    /// site can skip its own radio player bar — the app already shows one.
    /// Third-party links (Join It, ticketing, social, etc.) are left alone.
    private func kpcrEmbeddedURL(_ url: URL) -> URL {
        guard let host = url.host, host == "kpcr.org" || host.hasSuffix(".kpcr.org"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "app", value: "1"))
        components.queryItems = items
        return components.url ?? url
    }

    func showDetail(_ show: KPCRShow) {
        navigationController?.pushViewController(KPCRShowDetailViewController(show: show), animated: true)
    }

    func presentDrawer() {
        let drawer = KPCRDrawerViewController()
        drawer.modalPresentationStyle = .overFullScreen
        drawer.openURL = { [weak self] url in self?.dismiss(animated: true) { self?.open(url) } }
        drawer.shareApp = { [weak self] in
            self?.dismiss(animated: true) {
                let vc = UIActivityViewController(activityItems: ["Listen live to KPCR: https://kpcr.org"], applicationActivities: nil)
                self?.present(vc, animated: true)
            }
        }
        present(drawer, animated: false)
    }

    func presentProfile(startCreatingAccount: Bool = false) {
        let profile = KPCRProfileViewController(startCreatingAccount: startCreatingAccount)
        profile.modalPresentationStyle = .pageSheet
        if let sheet = profile.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(profile, animated: true)
    }
}

extension KPCRBaseViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        header.setLogoProgress(scrollView.contentOffset.y)
    }
}

private final class KPCRHeaderView: UIView {
    var menuAction: (() -> Void)?
    var avatarAction: (() -> Void)?
    private let logoBadge = UIView()
    private let logoSize: NSLayoutConstraint
    private var logoTapCount = 0
    private var lastLogoTapTime: CFTimeInterval = 0
    private weak var accountButton: UIButton?
    private weak var menuButton: UIButton?
    private var membershipToken: NSObjectProtocol?
    private var sessionToken: NSObjectProtocol?

    override init(frame: CGRect) {
        logoSize = logoBadge.widthAnchor.constraint(equalToConstant: 96)
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let membershipToken { NotificationCenter.default.removeObserver(membershipToken) }
        if let sessionToken { NotificationCenter.default.removeObserver(sessionToken) }
    }

    private func build() {
        backgroundColor = KPCRStyle.paper

        let menu = iconButton("line.3.horizontal")
        menu.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        menuButton = menu

        let logo = UIImageView(image: UIImage(named: "logo"))
        logo.contentMode = .scaleAspectFit
        logoBadge.backgroundColor = KPCRStyle.cyan
        logoBadge.layer.borderWidth = 2
        logoBadge.layer.borderColor = KPCRStyle.ink.cgColor
        logoBadge.layer.cornerRadius = 48
        logoBadge.clipsToBounds = true
        logoBadge.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(logoTapped)))

        logo.translatesAutoresizingMaskIntoConstraints = false
        logoBadge.translatesAutoresizingMaskIntoConstraints = false
        logoBadge.addSubview(logo)

        [menu, logoBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            menu.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            menu.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -26),
            menu.widthAnchor.constraint(equalToConstant: 44),
            menu.heightAnchor.constraint(equalToConstant: 44),

            logoBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoBadge.centerYAnchor.constraint(equalTo: menu.centerYAnchor, constant: -12),
            logoSize,
            logoBadge.heightAnchor.constraint(equalTo: logoBadge.widthAnchor),
            logo.centerXAnchor.constraint(equalTo: logoBadge.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: logoBadge.centerYAnchor),
            logo.widthAnchor.constraint(equalTo: logoBadge.widthAnchor, multiplier: 0.86),
            logo.heightAnchor.constraint(equalTo: logoBadge.heightAnchor, multiplier: 0.86),
        ])

        installAccountButton()

        sessionToken = NotificationCenter.default.addObserver(forName: KPCRSession.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.installAccountButton()
        }
    }

    /// Rebuilds the sign-in pill / avatar circle from scratch. Called at
    /// launch and again whenever `KPCRSession.didChange` fires, since
    /// sign-in/out normally happens from a sheet presented well after this
    /// header was already built.
    private func installAccountButton() {
        accountButton?.removeFromSuperview()
        if let membershipToken {
            NotificationCenter.default.removeObserver(membershipToken)
            self.membershipToken = nil
        }
        guard let menuButton else { return }

        let accountButton = KPCRSession.isLoggedIn ? avatarButton() : signInButton()
        accountButton.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)
        accountButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accountButton)
        self.accountButton = accountButton

        NSLayoutConstraint.activate([
            accountButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            accountButton.centerYAnchor.constraint(equalTo: menuButton.centerYAnchor),
            accountButton.widthAnchor.constraint(equalToConstant: KPCRSession.isLoggedIn ? 46 : 74),
            accountButton.heightAnchor.constraint(equalToConstant: KPCRSession.isLoggedIn ? 46 : 38),
        ])

        if KPCRSession.isLoggedIn, !KPCRSession.hasUploadedAvatar {
            refreshAvatarFromMembership()
            membershipToken = NotificationCenter.default.addObserver(forName: KPCRMembershipCache.didChange, object: nil, queue: .main) { [weak self] _ in
                self?.refreshAvatarFromMembership()
            }
        }
    }

    func setLogoProgress(_ offset: CGFloat) {
        logoSize.constant = 96
        logoBadge.layer.cornerRadius = 48
    }

    private func iconButton(_ system: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: system, withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)), for: .normal)
        button.tintColor = KPCRStyle.ink
        return button
    }

    private func signInButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Sign In", for: .normal)
        button.titleLabel?.font = KPCRStyle.rounded(15, weight: .black)
        button.tintColor = KPCRStyle.ink
        button.layer.borderWidth = 2
        button.layer.borderColor = KPCRStyle.ink.cgColor
        button.layer.cornerRadius = 19
        button.backgroundColor = KPCRStyle.paper
        return button
    }

    private func refreshAvatarFromMembership() {
        if let cached = KPCRMembershipCache.profileImageURL {
            applyAvatar(from: cached)
            return
        }
        Task {
            guard let payload = try? await KPCRAPI.fetchMembership() else { return }
            await MainActor.run { KPCRMembershipCache.store(payload) }
        }
    }

    private func applyAvatar(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        Task { [weak self] in
            guard let image = await NetworkService.fetchImage(from: url) else { return }
            await MainActor.run {
                self?.accountButton?.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
            }
        }
    }

    private func avatarButton() -> UIButton {
        let button = UIButton(type: .system)
        let image = KPCRSession.hasUploadedAvatar
            ? UIImage(named: "userAvatar")
            : KPCRAvatarAssets.image(index: KPCRSession.avatarIndex)
        button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.contentMode = .scaleAspectFill
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.layer.cornerRadius = 23
        button.layer.borderWidth = 2
        button.layer.borderColor = KPCRStyle.ink.cgColor
        button.backgroundColor = .clear
        button.clipsToBounds = true
        return button
    }

    @objc private func menuTapped() { menuAction?() }
    @objc private func avatarTapped() { avatarAction?() }

    @objc private func logoTapped() {
        let now = CACurrentMediaTime()
        logoTapCount = now - lastLogoTapTime < 0.42 ? min(logoTapCount + 1, 8) : 1
        lastLogoTapTime = now
        emitLightningBolts(count: min(3 + logoTapCount * 2, 18))
        pulseLogo()
    }

    private func pulseLogo() {
        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.92
        pulse.toValue = 1
        pulse.initialVelocity = 0.8
        pulse.damping = 7
        pulse.stiffness = 220
        pulse.mass = 0.45
        pulse.duration = 0.34
        logoBadge.layer.add(pulse, forKey: "kpcr.logo.pulse")
    }

    private func emitLightningBolts(count: Int) {
        layoutIfNeeded()
        let center = convert(CGPoint(x: logoBadge.bounds.midX, y: logoBadge.bounds.midY), from: logoBadge)
        let badgeRadius = max(logoBadge.bounds.width, logoBadge.bounds.height) / 2

        for index in 0..<count {
            let angle = (-CGFloat.pi * 0.95) + (CGFloat(index) / CGFloat(max(count - 1, 1))) * CGFloat.pi * 1.9 + CGFloat.random(in: -0.16...0.16)
            let distance = CGFloat.random(in: 42...92) + CGFloat(logoTapCount * 4)
            let start = point(from: center, angle: angle, distance: badgeRadius * 0.82)
            let midA = point(from: center, angle: angle, distance: badgeRadius + distance * 0.34)
            let midB = point(from: center, angle: angle, distance: badgeRadius + distance * 0.66)
            let end = point(from: center, angle: angle, distance: badgeRadius + distance)
            let normal = CGPoint(x: -sin(angle), y: cos(angle))
            let jag = CGFloat.random(in: 7...15)

            let path = UIBezierPath()
            path.move(to: start)
            path.addLine(to: CGPoint(x: midA.x + normal.x * jag, y: midA.y + normal.y * jag))
            path.addLine(to: CGPoint(x: midB.x - normal.x * jag, y: midB.y - normal.y * jag))
            path.addLine(to: end)

            let bolt = CAShapeLayer()
            bolt.path = path.cgPath
            bolt.fillColor = UIColor.clear.cgColor
            bolt.strokeColor = (index.isMultiple(of: 2) ? KPCRStyle.yellow : KPCRStyle.coral).cgColor
            bolt.lineWidth = CGFloat.random(in: 2.4...4.2)
            bolt.lineCap = .round
            bolt.lineJoin = .round
            bolt.shadowColor = KPCRStyle.yellow.cgColor
            bolt.shadowOpacity = 0.7
            bolt.shadowRadius = 5
            layer.addSublayer(bolt)

            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.duration = 0.16
            draw.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.beginTime = 0.18
            fade.duration = 0.34

            let group = CAAnimationGroup()
            group.animations = [draw, fade]
            group.duration = 0.54
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            bolt.add(group, forKey: "kpcr.logo.lightning")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
                bolt.removeFromSuperlayer()
            }
        }
    }

    private func point(from origin: CGPoint, angle: CGFloat, distance: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + cos(angle) * distance, y: origin.y + sin(angle) * distance)
    }
}

private final class KPCRHomeViewController: KPCRBaseViewController {
    private let recentHost = UIStackView()
    private let upNextHost = UIStackView()
    private var fallbackRecentTracks: [KPCRTrack] = KPCRAPI.sampleTracks
    private var notificationToken: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        recentHost.axis = .vertical
        recentHost.spacing = 0
        notificationToken = NotificationCenter.default.addObserver(forName: .kpcrNowPlayingChanged, object: nil, queue: .main) { [weak self] _ in
            self?.renderRecent()
        }
        load()
    }

    deinit {
        if let notificationToken { NotificationCenter.default.removeObserver(notificationToken) }
        refreshTask?.cancel()
    }

    private func load() {
        contentStack.addArrangedSubview(KPCRHeroCardView())
        contentStack.addArrangedSubview(sectionTitle("Recently Played"))
        contentStack.addArrangedSubview(recentHost)
        upNextHost.axis = .vertical
        upNextHost.spacing = 14
        contentStack.addArrangedSubview(sectionTitle("Up Next"))
        contentStack.addArrangedSubview(upNextHost)
        renderRecent()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                let payload = await KPCRAPI.fetchHome()
                await KPCRNowPlayingCenter.shared.setCurrentShow(payload.currentShow)
                await KPCRNowPlayingCenter.shared.setRecentTracks(payload.recentlyPlayed)
                render(payload)
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func render(_ payload: KPCRHomePayload) {
        fallbackRecentTracks = payload.recentlyPlayed.isEmpty ? fallbackRecentTracks : Array(payload.recentlyPlayed.prefix(10))
        renderRecent()
        upNextHost.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let shows = Array(payload.upNext.prefix(10))
        if shows.isEmpty {
            upNextHost.addArrangedSubview(KPCREmptyCardView(message: "Upcoming shows are unavailable. Check the mobile API at \(KPCRAPI.base)/api/mobile/home."))
        } else {
            for show in shows {
                upNextHost.addArrangedSubview(KPCRShowCardView(show: show) { [weak self] in
                    self?.showDetail(show)
                })
            }
        }
    }

    private func renderRecent() {
        recentHost.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let liveTracks = KPCRNowPlayingCenter.shared.recentTracks
        recentHost.addArrangedSubview(KPCRTrackCarouselView(tracks: liveTracks.isEmpty ? fallbackRecentTracks : liveTracks))
    }
}

private final class KPCRScheduleViewController: KPCRBaseViewController {
    private let daysStack = UIStackView()
    private let listStack = UIStackView()
    private var schedule: KPCRSchedulePayload = KPCRAPI.sampleSchedule
    private var selectedDay = "Monday"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KPCRStyle.ice
        scrollView.backgroundColor = KPCRStyle.ice
        setup()
        Task { @MainActor in
            schedule = await KPCRAPI.fetchSchedule()
            selectedDay = currentDayName()
            renderDays()
            renderShows()
        }
    }

    private func setup() {
        daysStack.axis = .horizontal
        daysStack.distribution = .fillEqually
        daysStack.spacing = 4
        listStack.axis = .vertical
        listStack.spacing = 18
        contentStack.addArrangedSubview(daysStack)
        contentStack.addArrangedSubview(listStack)
        renderDays()
        renderShows()
    }

    private func renderDays() {
        daysStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for day in schedule.days.map(\.day) {
            let button = UIButton(type: .system)
            button.setTitle(String(day.prefix(3)).uppercased(), for: .normal)
            button.titleLabel?.font = KPCRStyle.rounded(16, weight: .black)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.72
            button.titleLabel?.lineBreakMode = .byClipping
            button.tintColor = day == selectedDay ? .white : KPCRStyle.ink
            button.backgroundColor = day == selectedDay ? KPCRStyle.coral : .clear
            button.layer.cornerRadius = 5
            button.layer.borderWidth = day == selectedDay ? 2 : 0
            button.layer.borderColor = KPCRStyle.ink.cgColor
            button.addAction(UIAction { [weak self] _ in
                self?.selectedDay = day
                self?.renderDays()
                self?.renderShows()
            }, for: .touchUpInside)
            daysStack.addArrangedSubview(button)
        }
    }

    private func renderShows() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let shows = schedule.days.first { $0.day == selectedDay }?.shows ?? []
        if shows.isEmpty {
            listStack.addArrangedSubview(KPCREmptyCardView(message: "No shows listed for \(selectedDay)."))
        } else {
            for show in shows.prefix(10) {
                listStack.addArrangedSubview(KPCRShowCardView(show: show) { [weak self] in
                    self?.showDetail(show)
                })
            }
        }
    }

    private func currentDayName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: Date())
    }
}

private final class KPCRWinViewController: KPCRBaseViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.addArrangedSubview(sectionTitle("Win Tickets"))
        Task { @MainActor in
            let payload = await KPCRAPI.fetchGiveaways()
            let giveaways = payload.giveaways.isEmpty ? KPCRAPI.sampleGiveaways.giveaways : payload.giveaways
            for (index, item) in giveaways.enumerated() {
                contentStack.addArrangedSubview(KPCRGiveawayCardView(item: item, color: KPCRStyle.tileColor(index)) { [weak self] in
                    self?.open(item.giveawayUrl ?? "https://forms.gle/GwYXvzUwyZ24LDx28")
                })
            }
        }
    }
}

private final class KPCRComingSoonViewController: KPCRBaseViewController {
    private let titleText: String
    private let message: String

    init(titleText: String, message: String) {
        self.titleText = titleText
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.addArrangedSubview(sectionTitle(titleText))
        contentStack.addArrangedSubview(KPCREmptyCardView(message: message))
    }
}

private final class KPCRShowDetailViewController: KPCRBaseViewController {
    private let show: KPCRShow
    private let episodeStack = UIStackView()

    init(show: KPCRShow) {
        self.show = show
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "arrow.left.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .bold)), for: .normal)
        back.tintColor = KPCRStyle.ink
        back.contentHorizontalAlignment = .leading
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        contentStack.addArrangedSubview(back)
        contentStack.addArrangedSubview(showInfoCard())
        episodeStack.axis = .vertical
        episodeStack.spacing = 14
        contentStack.addArrangedSubview(episodeStack)
        loadEpisodes()
    }

    private func showInfoCard() -> UIView {
        let card = KPCRShadowCard()
        let image = KPCRSquareImageView(urlString: show.imageUrl)
        image.heightAnchor.constraint(equalToConstant: 250).isActive = true

        let title = label(show.title, 30, .black)
        title.numberOfLines = 0
        let host = label("w/ \(show.host)", 22, .regular)
        host.numberOfLines = 0
        let schedule = label(([show.day, show.time].compactMap { $0 }.joined(separator: " · ")).replacingOccurrences(of: ":00", with: ""), 18, .bold, KPCRStyle.red)
        schedule.numberOfLines = 0
        let description = label(show.description ?? "More show details coming soon.", 18, .regular)
        description.numberOfLines = 0

        let subscribe = UIButton(type: .system)
        subscribe.setTitle(KPCRFavoritesStore.shared.isFavorite(show: show) ? "♥ Subscribed" : "♡ Subscribe", for: .normal)
        subscribe.titleLabel?.font = KPCRStyle.rounded(22, weight: .regular)
        subscribe.tintColor = KPCRStyle.red
        subscribe.heightAnchor.constraint(equalToConstant: 60).isActive = true
        subscribe.addAction(UIAction { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await KPCRFavoritesStore.shared.toggle(show: self.show)
                subscribe.setTitle(KPCRFavoritesStore.shared.isFavorite(show: self.show) ? "♥ Subscribed" : "♡ Subscribe", for: .normal)
            }
        }, for: .touchUpInside)

        let info = UIStackView(arrangedSubviews: [image, title, host, schedule, description, subscribe])
        info.axis = .vertical
        info.spacing = 14
        card.addContent(info, insets: UIEdgeInsets(top: 18, left: 18, bottom: 0, right: 18))
        return card
    }

    private func loadEpisodes() {
        guard let feed = show.podcastRss, !feed.isEmpty else {
            episodeStack.addArrangedSubview(KPCREmptyCardView(message: "No podcast episodes available yet."))
            return
        }
        episodeStack.addArrangedSubview(KPCREmptyCardView(message: "Loading episodes..."))
        Task { @MainActor in
            let payload = await KPCRAPI.fetchPodcast(feedUrl: feed)
            renderEpisodes(payload.episodes)
        }
    }

    private func renderEpisodes(_ episodes: [KPCRPodcastEpisode]) {
        episodeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !episodes.isEmpty else {
            episodeStack.addArrangedSubview(KPCREmptyCardView(message: "No podcast episodes available yet."))
            return
        }
        let groups = Dictionary(grouping: episodes.prefix(24), by: { episodeDay($0.pubDate) })
        let days = groups.keys.sorted { lhs, rhs in
            episodeSortDate(lhs) > episodeSortDate(rhs)
        }
        for day in days {
            episodeStack.addArrangedSubview(KPCRPodcastDayCardView(day: day, episodes: Array(groups[day] ?? []), show: show))
        }
    }

    private func episodeDay(_ value: String?) -> String {
        guard let value, let date = ISO8601DateFormatter().date(from: value) ?? DateFormatter.rfc822.date(from: value) else {
            return "Recent Episodes"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date).uppercased()
    }

    private func episodeSortDate(_ label: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.date(from: label.capitalized) ?? .distantPast
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}

private enum KPCRMyKPCRSection {
    case shows
    case songs
    case signal
}

private final class KPCRMyPCRViewController: KPCRBaseViewController {
    private var favoritesToken: NSObjectProtocol?
    private var membershipPayload: KPCRMembershipPayload?
    private var membershipError: String?
    private var isLoadingMembership = false
    private var selectedSection: KPCRMyKPCRSection = .shows

    override func viewDidLoad() {
        super.viewDidLoad()
        favoritesToken = NotificationCenter.default.addObserver(forName: .kpcrFavoritesChanged, object: nil, queue: .main) { [weak self] _ in
            self?.render()
        }
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
        Task { @MainActor in await KPCRFavoritesStore.shared.load() }
        loadMembership()
    }

    deinit {
        if let favoritesToken { NotificationCenter.default.removeObserver(favoritesToken) }
    }

    private func render() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(sectionTitle("My KPCR"))
        if KPCRSession.isLoggedIn {
            contentStack.addArrangedSubview(KPCRMyKPCRTabsView(selected: selectedSection) { [weak self] section in
                self?.selectedSection = section
                self?.render()
                if section == .signal { self?.loadMembership(force: true) }
            })
            switch selectedSection {
            case .shows:
                let shows = KPCRFavoritesStore.shared.shows
                if shows.isEmpty {
                    contentStack.addArrangedSubview(KPCRActionEmptyCardView(
                        message: "You're not subscribed to any shows, head over to schedule and see what you like!",
                        actionTitle: "See schedule",
                        action: { [weak self] in self?.tabBarController?.selectedIndex = 1 }
                    ))
                } else {
                    shows.forEach { favorite in
                        contentStack.addArrangedSubview(KPCRShowCardView(show: favorite.item) { [weak self] in
                            self?.showDetail(favorite.item)
                        })
                    }
                }
            case .songs:
                let tracks = KPCRFavoritesStore.shared.tracks
                if tracks.isEmpty {
                    contentStack.addArrangedSubview(KPCRActionEmptyCardView(
                        message: "You haven't favorited any songs, head on over to the song history list or favorite songs you like while they're playing!",
                        actionTitle: "See song history",
                        action: { [weak self] in self?.tabBarController?.selectedIndex = 0 }
                    ))
                } else {
                    tracks.forEach { favorite in
                        contentStack.addArrangedSubview(KPCRFavoriteTrackRowView(track: favorite.item))
                    }
                }
            case .signal:
                contentStack.addArrangedSubview(KPCRSignalSocietyCard(
                    payload: membershipPayload,
                    isLoading: isLoadingMembership,
                    errorMessage: membershipError,
                    onOpen: { [weak self] url in self?.open(url) }
                ))
            }
        } else {
            contentStack.addArrangedSubview(KPCRLoginCardView(
                onSignIn: { [weak self] in self?.presentProfile() },
                onSignUp: { [weak self] in self?.presentProfile(startCreatingAccount: true) }
            ))
            contentStack.addArrangedSubview(KPCREmptyCardView(message: "Liked shows and songs, concert ticket giveaways and more!"))
            contentStack.addArrangedSubview(KPCRSignalSocietyCard(
                payload: membershipPayload,
                isLoading: isLoadingMembership,
                errorMessage: nil,
                onOpen: { [weak self] url in self?.open(url) }
            ))
        }
    }

    private func loadMembership(force: Bool = false) {
        guard KPCRSession.isLoggedIn, !isLoadingMembership else { return }
        if !force && membershipPayload != nil { return }
        isLoadingMembership = true
        render()
        Task { [weak self] in
            do {
                let payload = try await KPCRAPI.fetchMembership()
                await MainActor.run {
                    self?.membershipPayload = payload
                    self?.membershipError = nil
                    self?.isLoadingMembership = false
                    self?.render()
                    KPCRMembershipCache.store(payload)
                }
            } catch KPCRAPIError.authRequired {
                await MainActor.run {
                    KPCRSession.signOut()
                    self?.membershipPayload = nil
                    self?.membershipError = "Please sign in again."
                    self?.isLoadingMembership = false
                    self?.render()
                }
            } catch KPCRAPIError.server(let message) {
                await MainActor.run {
                    self?.membershipPayload = nil
                    self?.membershipError = message
                    self?.isLoadingMembership = false
                    self?.render()
                }
            } catch {
                await MainActor.run {
                    self?.membershipPayload = nil
                    self?.membershipError = "The KPCR backend could not check your membership right now."
                    self?.isLoadingMembership = false
                    self?.render()
                }
            }
        }
    }
}

private final class KPCRPodcastDayCardView: KPCRShadowCard {
    init(day: String, episodes: [KPCRPodcastEpisode], show: KPCRShow) {
        super.init(frame: .zero)
        let header = label(day, 22, .black)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.addArrangedSubview(header)
        for episode in episodes.prefix(6) {
            stack.addArrangedSubview(KPCRPodcastEpisodeRowView(episode: episode, show: show))
        }
        addContent(stack, insets: UIEdgeInsets(top: 18, left: 18, bottom: 10, right: 18))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRPodcastEpisodeRowView: UIView {
    private let episode: KPCRPodcastEpisode
    private let show: KPCRShow

    init(episode: KPCRPodcastEpisode, show: KPCRShow) {
        self.episode = episode
        self.show = show
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let image = KPCRSquareImageView(urlString: episode.image ?? show.imageUrl)
        let title = label(episode.title, 18, .black)
        title.numberOfLines = 2
        let date = label(formattedDate(episode.pubDate), 15, .bold, KPCRStyle.red)
        let text = UIStackView(arrangedSubviews: [title, date])
        text.axis = .vertical
        text.spacing = 6
        let play = UIButton(type: .system)
        play.setImage(UIImage(systemName: "play.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)), for: .normal)
        play.tintColor = KPCRStyle.ink
        play.addTarget(self, action: #selector(playEpisode), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [image, text, play])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            image.widthAnchor.constraint(equalToConstant: 74),
            image.heightAnchor.constraint(equalToConstant: 74),
            play.widthAnchor.constraint(equalToConstant: 44),
            play.heightAnchor.constraint(equalToConstant: 44),
        ])
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func formattedDate(_ value: String?) -> String {
        guard let value, let date = ISO8601DateFormatter().date(from: value) ?? DateFormatter.rfc822.date(from: value) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d · h:mm a"
        return formatter.string(from: date)
    }

    @objc private func playEpisode() {
        Task { @MainActor in
            await KPCRNowPlayingCenter.shared.playPodcastEpisode(episode, show: show)
        }
    }
}

private final class KPCRMiniPlayerView: UIView {
    private let artView = UIImageView(image: UIImage(named: "stationImage"))
    private let title = UILabel()
    private let subtitle = UILabel()
    private let heart = UIButton(type: .system)
    private let play = UIButton(type: .system)
    private let player = FRadioPlayer.shared
    private var notificationToken: NSObjectProtocol?
    private var favoritesToken: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KPCRStyle.cream
        layer.borderWidth = 2
        layer.borderColor = KPCRStyle.ink.cgColor

        artView.contentMode = .scaleAspectFill
        artView.backgroundColor = KPCRStyle.cyan
        artView.clipsToBounds = true
        artView.layer.cornerRadius = 6

        title.font = KPCRStyle.rounded(18, weight: .black)
        title.textColor = KPCRStyle.ink
        subtitle.font = KPCRStyle.rounded(14, weight: .medium)
        subtitle.textColor = UIColor.black.withAlphaComponent(0.72)
        let labels = UIStackView(arrangedSubviews: [title, subtitle])
        labels.axis = .vertical
        labels.spacing = 2

        heart.setImage(UIImage(systemName: "heart"), for: .normal)
        heart.tintColor = KPCRStyle.ink
        heart.addAction(UIAction { [weak self] _ in self?.toggleFavorite() }, for: .touchUpInside)

        let airplay = UIButton(type: .system)
        airplay.setImage(UIImage(systemName: "airplayaudio"), for: .normal)
        airplay.tintColor = KPCRStyle.ink

        play.setImage(UIImage(systemName: "play.fill"), for: .normal)
        play.tintColor = KPCRStyle.red
        play.backgroundColor = KPCRStyle.yellow
        play.layer.cornerRadius = 28
        play.layer.borderWidth = 2
        play.layer.borderColor = KPCRStyle.ink.cgColor
        play.addTarget(self, action: #selector(toggle), for: .touchUpInside)

        [artView, labels, heart, airplay, play].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            artView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            artView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artView.widthAnchor.constraint(equalToConstant: 52),
            artView.heightAnchor.constraint(equalToConstant: 52),
            labels.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: heart.leadingAnchor, constant: -12),
            heart.centerYAnchor.constraint(equalTo: centerYAnchor),
            heart.trailingAnchor.constraint(equalTo: airplay.leadingAnchor, constant: -20),
            heart.widthAnchor.constraint(equalToConstant: 34),
            heart.heightAnchor.constraint(equalToConstant: 34),
            airplay.centerYAnchor.constraint(equalTo: centerYAnchor),
            airplay.trailingAnchor.constraint(equalTo: play.leadingAnchor, constant: -18),
            airplay.widthAnchor.constraint(equalToConstant: 34),
            airplay.heightAnchor.constraint(equalToConstant: 34),
            play.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            play.centerYAnchor.constraint(equalTo: centerYAnchor),
            play.widthAnchor.constraint(equalToConstant: 56),
            play.heightAnchor.constraint(equalToConstant: 56),
        ])
        player.addObserver(self)
        notificationToken = NotificationCenter.default.addObserver(forName: .kpcrNowPlayingChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        favoritesToken = NotificationCenter.default.addObserver(forName: .kpcrFavoritesChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        Task { @MainActor in await KPCRFavoritesStore.shared.load() }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let notificationToken { NotificationCenter.default.removeObserver(notificationToken) }
        if let favoritesToken { NotificationCenter.default.removeObserver(favoritesToken) }
    }

    func refresh() {
        title.text = KPCRNowPlayingCenter.shared.displayTitle ?? player.currentMetadata?.trackName ?? StationsManager.shared.currentStation?.name ?? "KPCR 92.9FM"
        subtitle.text = KPCRNowPlayingCenter.shared.displayArtist ?? player.currentMetadata?.artistName ?? StationsManager.shared.currentStation?.desc ?? "Pirate Cat Radio"
        artView.image = KPCRNowPlayingCenter.shared.displayArtwork
        heart.setImage(UIImage(systemName: isCurrentFavorite() ? "heart.fill" : "heart"), for: .normal)
        let icon = player.isPlaying ? "stop.fill" : "play.fill"
        play.setImage(UIImage(systemName: icon), for: .normal)
    }

    private func isCurrentFavorite() -> Bool {
        if let show = KPCRNowPlayingCenter.shared.liveShowForDisplay {
            return KPCRFavoritesStore.shared.isFavorite(show: show)
        }
        guard let title = KPCRNowPlayingCenter.shared.currentTitle,
              let artist = KPCRNowPlayingCenter.shared.currentArtist else { return false }
        return KPCRFavoritesStore.shared.isFavorite(track: KPCRTrack(title: title, artist: artist, imageUrl: nil, airedAt: ""))
    }

    private func toggleFavorite() {
        if let show = KPCRNowPlayingCenter.shared.liveShowForDisplay {
            Task { @MainActor in await KPCRFavoritesStore.shared.toggle(show: show) }
            return
        }
        guard let trackTitle = KPCRNowPlayingCenter.shared.currentTitle,
              let trackArtist = KPCRNowPlayingCenter.shared.currentArtist else {
            showToast("  Nothing to save yet.  ")
            return
        }
        let track = KPCRTrack(title: trackTitle, artist: trackArtist, imageUrl: nil, airedAt: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))
        Task { @MainActor in await KPCRFavoritesStore.shared.toggle(track: track) }
    }

    @objc private func toggle() {
        if StationsManager.shared.currentStation == nil {
            StationsManager.shared.set(station: StationsManager.shared.stations.first)
        }
        if player.isPlaying, player.duration == 0 { player.stop() } else { player.togglePlaying() }
        refresh()
    }
}

extension KPCRMiniPlayerView: FRadioPlayerObserver {
    func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
        KPCRNowPlayingCenter.shared.refreshFromPlayer()
        refresh()
    }
    func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) { refresh() }
}

private final class KPCRShowCardView: KPCRShadowCard {
    private var onTap: (() -> Void)?

    init(show: KPCRShow, onTap: (() -> Void)? = nil) {
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 1.0, green: 0.976, blue: 0.929, alpha: 1)
        layer.cornerRadius = 19
        layer.borderWidth = 2.8
        layer.shadowColor = UIColor(red: 0.95, green: 0.75, blue: 0.24, alpha: 1).cgColor
        layer.shadowOffset = CGSize(width: 6, height: 7)
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let image = KPCRSquareImageView(urlString: show.imageUrl)
        let title = label(show.title, 18, .black)
        let host = label(show.host, 16, .regular)
        let time = label(Self.formattedTime(show.time), 16, .bold, UIColor(red: 0.78, green: 0.29, blue: 0.18, alpha: 1))
        title.numberOfLines = 1
        title.lineBreakMode = .byTruncatingTail
        title.minimumScaleFactor = 0.88
        title.adjustsFontSizeToFitWidth = true
        host.numberOfLines = 1
        host.lineBreakMode = .byTruncatingTail
        host.minimumScaleFactor = 0.9
        host.adjustsFontSizeToFitWidth = true
        time.numberOfLines = 1
        time.lineBreakMode = .byTruncatingTail
        let share = showCardIcon("square.and.arrow.up")
        let heart = showCardIcon(KPCRFavoritesStore.shared.isFavorite(show: show) ? "heart.fill" : "heart")
        let count = label("\(Self.favoriteCount(for: show))", 13, .medium, UIColor.black.withAlphaComponent(0.7))
        heart.addAction(UIAction { _ in
            Task { @MainActor in
                await KPCRFavoritesStore.shared.toggle(show: show)
                heart.setImage(UIImage(systemName: KPCRFavoritesStore.shared.isFavorite(show: show) ? "heart.fill" : "heart", withConfiguration: UIImage.SymbolConfiguration(pointSize: 29, weight: .medium)), for: .normal)
            }
        }, for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [share, heart, count])
        actions.axis = .horizontal
        actions.alignment = .center
        actions.spacing = 9
        [image, title, host, time, actions].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 138),
            image.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            image.centerYAnchor.constraint(equalTo: centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 96),
            image.heightAnchor.constraint(equalToConstant: 96),

            title.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            title.topAnchor.constraint(equalTo: image.topAnchor, constant: 8),

            host.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            host.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),

            time.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            time.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -12),
            time.topAnchor.constraint(equalTo: host.bottomAnchor, constant: 8),

            actions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            actions.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
        ])
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        host.setContentCompressionResistancePriority(.required, for: .horizontal)
        time.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        actions.setContentHuggingPriority(.required, for: .horizontal)
        actions.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        onTap?()
    }

    private func showCardIcon(_ name: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: name == "heart" || name == "heart.fill" ? 25 : 23, weight: .medium)), for: .normal)
        button.tintColor = KPCRStyle.ink
        button.imageView?.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    private static func formattedTime(_ value: String) -> String {
        value.replacingOccurrences(of: ":00", with: "").replacingOccurrences(of: "  ", with: " ")
    }

    private static func favoriteCount(for show: KPCRShow) -> Int {
        let source = show.slug ?? show.title
        return abs(source.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % 84 + 8
    }
}

private final class KPCRTrackCarouselView: UIScrollView {
    init(tracks: [KPCRTrack]) {
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
            heightAnchor.constraint(equalToConstant: 180),
        ])
        for track in tracks.prefix(10) {
            let card = KPCRTrackCardView(track: track)
            card.widthAnchor.constraint(equalToConstant: 178).isActive = true
            stack.addArrangedSubview(card)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRTrackCardView: KPCRShadowCard {
    init(track: KPCRTrack) {
        super.init(frame: .zero)
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.backgroundColor = KPCRStyle.cyan
        image.clipsToBounds = true
        image.layer.cornerRadius = 10
        image.layer.borderWidth = 1.5
        image.layer.borderColor = KPCRStyle.ink.cgColor

        // No-artwork placeholder: the KPCR cat mark at ~1/3 width, centered,
        // tinted black at low opacity — hidden once real artwork loads.
        let fallbackIcon = UIImageView(image: UIImage(named: "trackArtworkFallback")?.withRenderingMode(.alwaysTemplate))
        fallbackIcon.tintColor = UIColor.black.withAlphaComponent(0.3)
        fallbackIcon.contentMode = .scaleAspectFit
        fallbackIcon.translatesAutoresizingMaskIntoConstraints = false
        image.addSubview(fallbackIcon)
        NSLayoutConstraint.activate([
            fallbackIcon.centerXAnchor.constraint(equalTo: image.centerXAnchor),
            fallbackIcon.centerYAnchor.constraint(equalTo: image.centerYAnchor),
            fallbackIcon.widthAnchor.constraint(equalTo: image.widthAnchor, multiplier: 1.0 / 3.0),
            fallbackIcon.heightAnchor.constraint(equalTo: fallbackIcon.widthAnchor, multiplier: 81.0 / 100.0),
        ])
        func setArtwork(_ img: UIImage?) {
            guard let img else { return }
            image.image = img
            fallbackIcon.isHidden = true
        }

        if let imageUrl = track.imageUrl, let url = URL(string: imageUrl) {
            Task {
                let fetched = await NetworkService.fetchImage(from: url)
                await MainActor.run { setArtwork(fetched) }
            }
        } else if let cached = KPCRNowPlayingCenter.shared.artwork(for: track.title, artist: track.artist) {
            setArtwork(cached)
        } else {
            KPCRNowPlayingCenter.shared.fetchArtwork(for: track)
            _ = NotificationCenter.default.addObserver(forName: .kpcrNowPlayingChanged, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    if image.image == nil, let cached = KPCRNowPlayingCenter.shared.artwork(for: track.title, artist: track.artist) {
                        setArtwork(cached)
                    }
                }
            }
        }
        let gradient = UIView()
        gradient.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        let title = label(track.title, 17, .black, .white)
        let artist = label(track.artist, 14, .bold, .white)
        let heart = icon(KPCRFavoritesStore.shared.isFavorite(track: track) ? "heart.fill" : "heart", .white)
        heart.addAction(UIAction { _ in
            Task { @MainActor in
                await KPCRFavoritesStore.shared.toggle(track: track)
                heart.setImage(UIImage(systemName: KPCRFavoritesStore.shared.isFavorite(track: track) ? "heart.fill" : "heart", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)), for: .normal)
            }
        }, for: .touchUpInside)
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        artist.numberOfLines = 1
        artist.lineBreakMode = .byTruncatingTail
        let v = UIStackView(arrangedSubviews: [UIView(), title, artist])
        v.axis = .vertical
        v.spacing = 2
        [image, gradient, v, heart].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: topAnchor),
            image.leadingAnchor.constraint(equalTo: leadingAnchor),
            image.trailingAnchor.constraint(equalTo: trailingAnchor),
            image.bottomAnchor.constraint(equalTo: bottomAnchor),
            gradient.topAnchor.constraint(equalTo: topAnchor),
            gradient.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradient.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradient.bottomAnchor.constraint(equalTo: bottomAnchor),
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(lessThanOrEqualTo: heart.leadingAnchor, constant: -8),
            v.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heart.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            heart.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRHeroCardView: KPCRShadowCard {
    private let artwork = UIImageView()
    private let fallbackIcon = UIImageView(image: UIImage(named: "trackArtworkFallback")?.withRenderingMode(.alwaysTemplate))
    private let trackTitle = label("Currently Playing", 28, .black)
    private let artistName = label("Waiting for track info", 18, .medium)
    private var notificationToken: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KPCRStyle.purple

        artwork.contentMode = .scaleAspectFill
        artwork.backgroundColor = KPCRStyle.cyan
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 10
        artwork.layer.borderWidth = 2
        artwork.layer.borderColor = KPCRStyle.ink.cgColor

        fallbackIcon.tintColor = UIColor.black.withAlphaComponent(0.3)
        fallbackIcon.contentMode = .scaleAspectFit
        fallbackIcon.translatesAutoresizingMaskIntoConstraints = false
        artwork.addSubview(fallbackIcon)
        NSLayoutConstraint.activate([
            fallbackIcon.centerXAnchor.constraint(equalTo: artwork.centerXAnchor),
            fallbackIcon.centerYAnchor.constraint(equalTo: artwork.centerYAnchor),
            fallbackIcon.widthAnchor.constraint(equalTo: artwork.widthAnchor, multiplier: 1.0 / 3.0),
            fallbackIcon.heightAnchor.constraint(equalTo: fallbackIcon.widthAnchor, multiplier: 81.0 / 100.0),
        ])

        let section = label("Currently playing:", 17, .bold)
        let dividerTop = UIView()
        dividerTop.backgroundColor = KPCRStyle.ink
        let dividerBottom = UIView()
        dividerBottom.backgroundColor = KPCRStyle.ink

        trackTitle.numberOfLines = 2
        artistName.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [dividerTop, section, dividerBottom, artwork, trackTitle, artistName])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        addContent(stack, insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
        dividerTop.heightAnchor.constraint(equalToConstant: 2).isActive = true
        dividerBottom.heightAnchor.constraint(equalToConstant: 2).isActive = true
        artwork.heightAnchor.constraint(equalToConstant: 230).isActive = true
        notificationToken = NotificationCenter.default.addObserver(forName: .kpcrNowPlayingChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let notificationToken { NotificationCenter.default.removeObserver(notificationToken) }
    }

    private func refresh() {
        trackTitle.text = KPCRNowPlayingCenter.shared.displayTitle ?? "Live from KPCR 92.9FM"
        artistName.text = KPCRNowPlayingCenter.shared.displayArtist ?? "Pirate Cat Radio"
        let image = KPCRNowPlayingCenter.shared.displayArtwork
        artwork.image = image
        fallbackIcon.isHidden = image != nil
    }
}

private final class KPCRGiveawayCardView: KPCRShadowCard {
    private let onTap: (() -> Void)?

    init(item: KPCRGiveaway, color: UIColor = KPCRStyle.green, onTap: (() -> Void)? = nil) {
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = color
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let title = label(item.title, 18, .black)
        let venue = label([item.venue, item.city].compactMap { $0 }.joined(separator: " · "), 15, .regular)
        let enter = label("Enter to win ->", 15, .bold, KPCRStyle.ink)
        let image = item.imageUrl == nil ? KPCRTicketFallbackView() : KPCRSquareImageView(urlString: item.imageUrl)
        let stack = UIStackView(arrangedSubviews: [title, venue, enter])
        stack.axis = .vertical
        stack.spacing = 6
        title.numberOfLines = 1
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.82
        venue.numberOfLines = 1
        venue.adjustsFontSizeToFitWidth = true
        venue.minimumScaleFactor = 0.85
        let row = UIStackView(arrangedSubviews: [image, stack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        addContent(row, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 14))
        image.widthAnchor.constraint(equalToConstant: 78).isActive = true
        image.heightAnchor.constraint(equalToConstant: 78).isActive = true
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        onTap?()
    }
}

private final class KPCRTicketFallbackView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KPCRStyle.yellow
        layer.cornerRadius = 8
        layer.borderWidth = 1.5
        layer.borderColor = KPCRStyle.ink.cgColor
        let icon = UIImageView(image: UIImage(systemName: "ticket.fill"))
        icon.tintColor = KPCRStyle.red
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRLoginCardView: KPCRShadowCard {
    private let onSignIn: (() -> Void)?
    private let onSignUp: (() -> Void)?

    init(onSignIn: (() -> Void)? = nil, onSignUp: (() -> Void)? = nil) {
        self.onSignIn = onSignIn
        self.onSignUp = onSignUp
        super.init(frame: .zero)
        backgroundColor = KPCRStyle.ice
        let signIn = UIButton(type: .system)
        signIn.setTitle("Sign In", for: .normal)
        signIn.titleLabel?.font = KPCRStyle.rounded(18, weight: .black)
        signIn.tintColor = .white
        signIn.backgroundColor = KPCRStyle.coral
        signIn.layer.cornerRadius = 10
        signIn.layer.borderWidth = 2
        signIn.layer.borderColor = KPCRStyle.ink.cgColor
        signIn.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        let signUp = UIButton(type: .system)
        signUp.setTitle("Sign up", for: .normal)
        signUp.titleLabel?.font = KPCRStyle.rounded(18, weight: .black)
        signUp.tintColor = KPCRStyle.ink
        signUp.backgroundColor = KPCRStyle.cyan
        signUp.layer.cornerRadius = 10
        signUp.layer.borderWidth = 2
        signUp.layer.borderColor = KPCRStyle.ink.cgColor
        signUp.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [signIn, signUp])
        stack.axis = .vertical
        stack.spacing = 14
        addContent(stack, insets: UIEdgeInsets(top: 24, left: 22, bottom: 24, right: 22))
        signIn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        signUp.heightAnchor.constraint(equalToConstant: 52).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func signInTapped() {
        onSignIn?()
    }

    @objc private func signUpTapped() {
        onSignUp?()
    }
}

private final class KPCRFavoritesSummaryCard: KPCRShadowCard {
    init(shows: [KPCRFavoriteShow], tracks: [KPCRFavoriteTrack]) {
        super.init(frame: .zero)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.addArrangedSubview(label("Saved Favorites", 22, .black))

        if shows.isEmpty && tracks.isEmpty {
            let empty = label("Liked shows and songs will appear here.", 18, .black)
            empty.numberOfLines = 0
            stack.addArrangedSubview(empty)
        } else {
            if !shows.isEmpty {
                stack.addArrangedSubview(section("Liked Shows"))
                shows.prefix(5).forEach { favorite in
                    stack.addArrangedSubview(row(title: favorite.item.title, subtitle: favorite.item.host, icon: "dot.radiowaves.left.and.right"))
                }
            }
            if !tracks.isEmpty {
                stack.addArrangedSubview(section("Liked Songs"))
                tracks.prefix(8).forEach { favorite in
                    stack.addArrangedSubview(row(title: favorite.item.title, subtitle: favorite.item.artist, icon: "music.note"))
                }
            }
        }

        addContent(stack, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func section(_ text: String) -> UILabel {
        let label = label(text.uppercased(), 14, .black, KPCRStyle.red)
        return label
    }

    private func row(title: String, subtitle: String, icon: String) -> UIView {
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = KPCRStyle.blue
        symbol.contentMode = .scaleAspectFit
        let titleLabel = label(title, 17, .black)
        titleLabel.lineBreakMode = .byTruncatingTail
        let subtitleLabel = label(subtitle, 14, .regular)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.68)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [symbol, text])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 24),
            symbol.heightAnchor.constraint(equalToConstant: 24),
        ])
        return row
    }
}

private final class KPCRMyKPCRTabsView: UIView {
    private let onSelect: (KPCRMyKPCRSection) -> Void

    init(selected: KPCRMyKPCRSection, onSelect: @escaping (KPCRMyKPCRSection) -> Void) {
        self.onSelect = onSelect
        super.init(frame: .zero)
        backgroundColor = KPCRStyle.paper
        let shows = button("Shows", section: .shows, selected: selected == .shows)
        let songs = button("Songs", section: .songs, selected: selected == .songs)
        let signal = button("Signal Society", section: .signal, selected: selected == .signal)
        let stack = UIStackView(arrangedSubviews: [shows, songs, signal])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func button(_ title: String, section: KPCRMyKPCRSection, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title.uppercased(), for: .normal)
        button.titleLabel?.font = KPCRStyle.rounded(16, weight: .black)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.tintColor = selected ? .white : KPCRStyle.ink
        button.backgroundColor = selected ? KPCRStyle.red : .clear
        button.layer.cornerRadius = 5
        button.layer.borderWidth = selected ? 2.5 : 0
        button.layer.borderColor = KPCRStyle.ink.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 6, bottom: 9, right: 6)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.onSelect(section) }, for: .touchUpInside)
        return button
    }
}

private final class KPCRActionEmptyCardView: KPCRShadowCard {
    private let action: (() -> Void)?

    init(message: String, actionTitle: String, action: (() -> Void)? = nil) {
        self.action = action
        super.init(frame: .zero)
        backgroundColor = .white
        let messageLabel = label(message, 26, .black)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        let divider = UIView()
        divider.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        let actionButton = UIButton(type: .system)
        actionButton.setTitle("->  \(actionTitle)", for: .normal)
        actionButton.titleLabel?.font = KPCRStyle.rounded(23, weight: .regular)
        actionButton.tintColor = KPCRStyle.red
        actionButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [messageLabel, divider, actionButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        addContent(stack, insets: UIEdgeInsets(top: 48, left: 26, bottom: 42, right: 26))
        divider.heightAnchor.constraint(equalToConstant: 2).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        action?()
    }
}

private final class KPCRFavoriteTrackRowView: KPCRShadowCard {
    init(track: KPCRTrack) {
        super.init(frame: .zero)
        let image = KPCRSquareImageView(urlString: track.imageUrl)
        if track.imageUrl == nil, let cached = KPCRNowPlayingCenter.shared.artwork(for: track.title, artist: track.artist) {
            image.image = cached
            image.contentMode = .scaleAspectFill
        } else if track.imageUrl == nil {
            KPCRNowPlayingCenter.shared.fetchArtwork(for: track)
            _ = NotificationCenter.default.addObserver(forName: .kpcrNowPlayingChanged, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    if let cached = KPCRNowPlayingCenter.shared.artwork(for: track.title, artist: track.artist) {
                        image.image = cached
                        image.contentMode = .scaleAspectFill
                    }
                }
            }
        }

        let title = label(track.title, 22, .black)
        title.numberOfLines = 1
        title.lineBreakMode = .byTruncatingTail
        let artist = label(track.artist, 17, .regular)
        artist.numberOfLines = 1
        artist.lineBreakMode = .byTruncatingTail
        let aired = label("Aired on: \(track.airedAt)", 15, .bold, KPCRStyle.red)
        aired.numberOfLines = 1
        aired.lineBreakMode = .byTruncatingTail
        let text = UIStackView(arrangedSubviews: [title, artist, aired])
        text.axis = .vertical
        text.spacing = 7

        let heart = icon("heart.fill", KPCRStyle.red)
        heart.addAction(UIAction { _ in
            Task { @MainActor in
                await KPCRFavoritesStore.shared.toggle(track: track)
            }
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [image, text, heart])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14
        addContent(row, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        image.widthAnchor.constraint(equalToConstant: 86).isActive = true
        image.heightAnchor.constraint(equalToConstant: 86).isActive = true
        heart.setContentHuggingPriority(.required, for: .horizontal)
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRDigitalMemberCardView: UIView {
    private let membership: KPCRMembership
    private let portrait = UIImageView()
    private let qrCode = UIImageView()

    init(membership: KPCRMembership) {
        self.membership = membership
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        backgroundColor = .black
        layer.cornerRadius = 18
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.36).cgColor
        clipsToBounds = true

        let mark = UIImageView(image: UIImage(named: "catEyesMark")?.withRenderingMode(.alwaysTemplate))
        mark.tintColor = KPCRStyle.yellow
        mark.contentMode = .scaleAspectFit

        let title = label("KPCR - Signal Society", 19, .black, .white)
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.68
        title.numberOfLines = 1

        let statusKicker = label("STATUS", 12, .black, .white)
        statusKicker.textAlignment = .right
        let status = label(membership.statusLabel, 21, .regular, KPCRStyle.yellow)
        status.textAlignment = .right
        status.numberOfLines = 1
        status.adjustsFontSizeToFitWidth = true
        status.minimumScaleFactor = 0.74

        let nameKicker = label("MEMBER'S NAME", 12, .black, .white)
        let name = label(memberName(), 29, .regular, KPCRStyle.yellow)
        name.numberOfLines = 1
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.54

        let typeKicker = label("MEMBERSHIP TYPE", 12, .black, .white)
        let type = label((membership.membershipTypeName ?? "Signal Society").uppercased(), 17, .regular, KPCRStyle.yellow)
        type.numberOfLines = 2
        type.adjustsFontSizeToFitWidth = true
        type.minimumScaleFactor = 0.56

        let expirationKicker = label("EXPIRATION", 12, .black, .white)
        let expiration = label(formattedDate(membership.expirationDate) ?? "Not available", 17, .regular, KPCRStyle.yellow)
        expiration.numberOfLines = 1
        expiration.adjustsFontSizeToFitWidth = true
        expiration.minimumScaleFactor = 0.7

        let memberIdKicker = label("MEMBERSHIP ID", 12, .black, .white)
        let memberId = label(shortMembershipId(), 17, .regular, KPCRStyle.yellow)
        memberId.numberOfLines = 1
        memberId.adjustsFontSizeToFitWidth = true
        memberId.minimumScaleFactor = 0.62

        portrait.contentMode = .scaleAspectFill
        portrait.clipsToBounds = true
        portrait.backgroundColor = KPCRStyle.paper
        portrait.layer.cornerRadius = 44
        portrait.layer.borderWidth = 1
        portrait.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        portrait.image = KPCRAvatarAssets.image(index: KPCRSession.avatarIndex)
        loadPortrait()

        qrCode.contentMode = .scaleAspectFit
        qrCode.backgroundColor = .white
        qrCode.layer.cornerRadius = 6
        qrCode.clipsToBounds = true
        qrCode.image = makeQRCode()

        let views = [mark, title, statusKicker, status, nameKicker, name, portrait, typeKicker, type, memberIdKicker, memberId, expirationKicker, expiration, qrCode]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 610),

            mark.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            mark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            mark.widthAnchor.constraint(equalToConstant: 60),
            mark.heightAnchor.constraint(equalTo: mark.widthAnchor, multiplier: 23.0 / 64.0),

            title.centerYAnchor.constraint(equalTo: mark.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: mark.trailingAnchor, constant: 12),
            title.trailingAnchor.constraint(lessThanOrEqualTo: statusKicker.leadingAnchor, constant: -14),

            statusKicker.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            statusKicker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            statusKicker.widthAnchor.constraint(equalToConstant: 86),

            status.topAnchor.constraint(equalTo: statusKicker.bottomAnchor, constant: -1),
            status.trailingAnchor.constraint(equalTo: statusKicker.trailingAnchor),
            status.widthAnchor.constraint(equalTo: statusKicker.widthAnchor),

            nameKicker.topAnchor.constraint(equalTo: topAnchor, constant: 122),
            nameKicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),

            name.topAnchor.constraint(equalTo: nameKicker.bottomAnchor, constant: 8),
            name.leadingAnchor.constraint(equalTo: nameKicker.leadingAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: portrait.leadingAnchor, constant: -20),

            portrait.topAnchor.constraint(equalTo: topAnchor, constant: 122),
            portrait.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            portrait.widthAnchor.constraint(equalToConstant: 88),
            portrait.heightAnchor.constraint(equalToConstant: 88),

            typeKicker.topAnchor.constraint(equalTo: name.topAnchor, constant: 126),
            typeKicker.leadingAnchor.constraint(equalTo: nameKicker.leadingAnchor),
            typeKicker.trailingAnchor.constraint(lessThanOrEqualTo: memberIdKicker.leadingAnchor, constant: -18),

            type.topAnchor.constraint(equalTo: typeKicker.bottomAnchor, constant: 7),
            type.leadingAnchor.constraint(equalTo: typeKicker.leadingAnchor),
            type.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -14),

            memberIdKicker.topAnchor.constraint(equalTo: typeKicker.topAnchor),
            memberIdKicker.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 10),
            memberIdKicker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            memberId.topAnchor.constraint(equalTo: memberIdKicker.bottomAnchor, constant: 7),
            memberId.leadingAnchor.constraint(equalTo: memberIdKicker.leadingAnchor),
            memberId.trailingAnchor.constraint(equalTo: memberIdKicker.trailingAnchor),

            expirationKicker.topAnchor.constraint(equalTo: type.bottomAnchor, constant: 18),
            expirationKicker.leadingAnchor.constraint(equalTo: nameKicker.leadingAnchor),

            expiration.topAnchor.constraint(equalTo: expirationKicker.bottomAnchor, constant: 7),
            expiration.leadingAnchor.constraint(equalTo: expirationKicker.leadingAnchor),
            expiration.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -14),

            qrCode.topAnchor.constraint(greaterThanOrEqualTo: expiration.bottomAnchor, constant: 48),
            qrCode.centerXAnchor.constraint(equalTo: centerXAnchor),
            qrCode.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -26),
            qrCode.widthAnchor.constraint(equalToConstant: 136),
            qrCode.heightAnchor.constraint(equalTo: qrCode.widthAnchor),
        ])
    }

    private func memberName() -> String {
        membership.memberName
            ?? KPCRSession.currentUser?.displayName
            ?? KPCRSession.currentUser?.username
            ?? KPCRSession.currentUser?.email
            ?? "KPCR Member"
    }

    private func shortMembershipId() -> String {
        let raw = (membership.memberNumber ?? membership.cardNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Not available" }
        return raw.uppercased()
    }

    private func loadPortrait() {
        guard let urlString = membership.profileImageURL ?? membership.profileImageUrl, let url = URL(string: urlString) else { return }
        Task {
            let fetched = await NetworkService.fetchImage(from: url)
            await MainActor.run {
                if let fetched { self.portrait.image = fetched }
            }
        }
    }

    private func makeQRCode() -> UIImage? {
        let value = membership.qrCodeUrl
            ?? membership.memberNumber
            ?? membership.cardNumber
            ?? "KPCR Signal Society"
        guard let data = value.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return UIImage(ciImage: scaled)
    }

    private func formattedDate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

private final class KPCRSignalSocietyCard: KPCRShadowCard {
    private let checkoutUrl: String?
    private let cardUrl: String?
    private let walletUrl: String?
    private let onOpen: ((String) -> Void)?

    init(payload: KPCRMembershipPayload?, isLoading: Bool, errorMessage: String? = nil, onOpen: ((String) -> Void)? = nil) {
        self.checkoutUrl = payload?.checkoutUrl
        self.cardUrl = payload?.membership.cardUrl
        self.walletUrl = payload?.membership.walletUrl
        self.onOpen = onOpen
        super.init(frame: .zero)
        if payload?.membership != nil {
            backgroundColor = .clear
            layer.borderWidth = 0
            layer.shadowOpacity = 0
            layer.cornerRadius = 0
        } else {
            backgroundColor = KPCRStyle.paper
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16

        if isLoading {
            stack.addArrangedSubview(header(title: "Signal Society", subtitle: "Checking your membership...", isActive: false))
        } else if let membership = payload?.membership {
            if membership.status == 100 {
                stack.addArrangedSubview(memberCardBlock(membership: membership))
                if checkoutUrl != nil {
                    stack.addArrangedSubview(actionRow(primaryTitle: "Upgrade membership", secondaryTitle: nil))
                }
            } else {
                stack.addArrangedSubview(header(
                    title: "Signal Society",
                    subtitle: membership.statusLabel,
                    isActive: false
                ))
                stack.addArrangedSubview(statusBlock(membership))
                stack.addArrangedSubview(body("Join or renew to unlock member perks, double giveaway entries, and your digital card."))
                if checkoutUrl != nil {
                    stack.addArrangedSubview(actionRow(primaryTitle: "Sign up or renew", secondaryTitle: nil))
                }
            }
        } else if KPCRSession.isLoggedIn {
            stack.addArrangedSubview(header(title: "Signal Society", subtitle: "Account not matched", isActive: false))
            let email = KPCRSession.currentUser?.email ?? "this account"
            stack.addArrangedSubview(body(errorMessage ?? "No Signal Society membership was found for \(email). Sign in with the email on your Join It membership."))
        } else {
            stack.addArrangedSubview(header(title: "Signal Society", subtitle: "Sign in required", isActive: false))
            stack.addArrangedSubview(body("Sign in to check your Signal Society membership, view your member card, and unlock member perks."))
        }

        let insets = payload?.membership != nil
            ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            : UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        addContent(stack, insets: insets)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func header(title: String, subtitle: String, isActive: Bool) -> UIView {
        let panel = UIView()
        panel.backgroundColor = KPCRStyle.cyan
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 2
        panel.layer.borderColor = KPCRStyle.ink.cgColor

        let titleLabel = label(title, 24, .black)
        let subtitleLabel = label(subtitle, 15, .black)
        subtitleLabel.numberOfLines = 1

        let badge = UILabel()
        badge.text = isActive ? "ACTIVE" : "STATUS"
        badge.font = KPCRStyle.rounded(11, weight: .black)
        badge.textColor = isActive ? .white : KPCRStyle.ink
        badge.textAlignment = .center
        badge.backgroundColor = isActive ? KPCRStyle.green : KPCRStyle.yellow
        badge.layer.cornerRadius = 13
        badge.layer.borderWidth = 1.5
        badge.layer.borderColor = KPCRStyle.ink.cgColor
        badge.clipsToBounds = true

        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [text, badge])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
            badge.widthAnchor.constraint(equalToConstant: 72),
            badge.heightAnchor.constraint(equalToConstant: 28),
        ])
        return panel
    }

    private func statusBlock(_ membership: KPCRMembership?) -> UIView {
        let card = UIView()
        card.backgroundColor = .clear

        let status = infoRow(labelText: "Status", value: membership?.statusLabel ?? "Unavailable")
        let typeText = membership?.membershipTypeName?.isEmpty == false ? membership?.membershipTypeName : "Signal Society"
        let type = infoRow(labelText: "Plan", value: typeText ?? "Signal Society")
        let expiration = infoRow(labelText: "Renews", value: formattedDate(membership?.expirationDate) ?? "Not available")

        let stack = UIStackView(arrangedSubviews: [status, type, expiration])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func infoRow(labelText: String, value: String) -> UIView {
        let key = label(labelText.uppercased(), 12, .black, UIColor.black.withAlphaComponent(0.55))
        let valueLabel = label(value, 16, .bold)
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        let row = UIStackView(arrangedSubviews: [key, valueLabel])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        key.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func memberCardBlock(membership: KPCRMembership) -> UIView {
        let stack = UIStackView(arrangedSubviews: [KPCRDigitalMemberCardView(membership: membership)])
        stack.axis = .vertical
        stack.spacing = 10
        if walletUrl != nil {
            stack.addArrangedSubview(actionButton(title: "Add to Apple Wallet", color: .black, action: #selector(walletTapped)))
        }
        return stack
    }

    private func body(_ text: String) -> UILabel {
        let label = label(text, 17, .bold)
        label.numberOfLines = 0
        return label
    }

    private func joinButton(title: String = "Join Signal Society") -> UIButton {
        actionButton(title: title, color: KPCRStyle.ink, action: #selector(joinTapped))
    }

    private func actionRow(primaryTitle: String, secondaryTitle: String?) -> UIView {
        let primary = joinButton(title: primaryTitle)
        if let secondaryTitle {
            let secondary = actionButton(title: secondaryTitle, color: KPCRStyle.blue, action: #selector(cardTapped))
            let row = UIStackView(arrangedSubviews: [primary, secondary])
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually
            return row
        }
        return primary
    }

    private func actionButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = KPCRStyle.rounded(16, weight: .black)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.78
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func formattedDate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    @objc private func joinTapped() {
        guard let checkoutUrl else { return }
        onOpen?(checkoutUrl)
    }

    @objc private func cardTapped() {
        guard let cardUrl else { return }
        onOpen?(cardUrl)
    }

    @objc private func walletTapped() {
        guard let walletUrl else { return }
        onOpen?(walletUrl)
    }
}

private final class KPCRMenuCardView: KPCRShadowCard {
    init(title: String, rows: [String]) {
        super.init(frame: .zero)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(label(title, 22, .black))
        for row in rows { stack.addArrangedSubview(label(row, 17, .regular)) }
        addContent(stack, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCREmptyCardView: KPCRShadowCard {
    init(message: String) {
        super.init(frame: .zero)
        backgroundColor = KPCRStyle.cyan
        let text = label(message, 22, .black)
        text.numberOfLines = 0
        text.textAlignment = .center
        addContent(text, insets: UIEdgeInsets(top: 36, left: 24, bottom: 36, right: 24))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private class KPCRShadowCard: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KPCRStyle.paper
        layer.cornerRadius = 10
        layer.borderWidth = 2
        layer.borderColor = KPCRStyle.ink.cgColor
        layer.shadowColor = KPCRStyle.yellow.cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 7, height: 8)
        layer.shadowRadius = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func addContent(_ view: UIView, insets: UIEdgeInsets) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ])
    }
}

private final class KPCRSquareImageView: UIImageView {
    init(urlString: String?) {
        super.init(frame: .zero)
        image = UIImage(named: "stationImage")
        contentMode = urlString == nil ? .scaleAspectFit : .scaleAspectFill
        backgroundColor = KPCRStyle.paper
        clipsToBounds = true
        layer.cornerRadius = 8
        layer.borderWidth = 1.5
        layer.borderColor = KPCRStyle.ink.cgColor
        if let urlString, let url = URL(string: urlString) {
            Task {
                let fetched = await NetworkService.fetchImage(from: url)
                await MainActor.run { if let fetched { self.image = fetched } }
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRDrawerViewController: UIViewController {
    var openURL: ((String) -> Void)?
    var shareApp: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.46)
        let panel = UIView()
        panel.backgroundColor = KPCRStyle.drawer
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        addHeader("Support Us", to: stack)
        addRow("calendar", "Events", to: stack) { [weak self] in self?.openURL?("https://kpcr.org/events") }
        addRow("heart.fill", "Donate", to: stack) { [weak self] in self?.openURL?("https://kpcr.org/donate") }
        addHeader("Social", to: stack)
        addRow("square.and.arrow.up", "Share App", to: stack) { [weak self] in self?.shareApp?() }
        addRow("f.circle.fill", "Facebook", to: stack) { [weak self] in self?.openURL?("https://www.facebook.com/kpcrfm") }
        addRow("camera", "Instagram", to: stack) { [weak self] in self?.openURL?("https://www.instagram.com/kpcrfm/") }
        addRow("play.rectangle.fill", "YouTube", to: stack) { [weak self] in self?.openURL?("https://www.youtube.com/@kpcrfm") }
        addHeader("More", to: stack)
        addRow("star", "Review This App", to: stack) { [weak self] in self?.openURL?("https://kpcr.org") }
        addRow("ladybug", "Submit a Bug", to: stack) { [weak self] in self?.openURL?("https://kpcr.org/report-a-bug") }
        addRow("hand.raised", "Privacy Policy", to: stack) { [weak self] in self?.openURL?("https://kpcr.org/privacy-policy") }

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.70),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 44),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(close))
        view.addGestureRecognizer(tap)
        panel.addGestureRecognizer(UITapGestureRecognizer())
    }

    private func addHeader(_ text: String, to stack: UIStackView) {
        let header = label(text.uppercased(), 20, .black, .white)
        stack.addArrangedSubview(header)
    }

    private func addRow(_ icon: String, _ text: String, to stack: UIStackView, action: @escaping () -> Void) {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.contentHorizontalAlignment = .leading
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.imagePadding = 12
        config.title = text
        config.baseForegroundColor = .white
        button.configuration = config
        button.titleLabel?.font = KPCRStyle.rounded(22, weight: .regular)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    @objc private func close() { dismiss(animated: false) }
}

private final class KPCRProfileViewController: UIViewController {
    private let modeControl = UISegmentedControl(items: ["Sign In", "Create"])
    private let contentStack = UIStackView()
    private let status = UILabel()
    private let startCreatingAccount: Bool
    private weak var emailField: UITextField?
    private weak var usernameField: UITextField?
    private weak var passwordField: UITextField?
    private weak var primaryButton: UIButton?

    init(startCreatingAccount: Bool = false) {
        self.startCreatingAccount = startCreatingAccount
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KPCRStyle.cream
        build()
        render()
    }

    private func build() {
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)), for: .normal)
        close.tintColor = KPCRStyle.ink
        close.contentHorizontalAlignment = .trailing
        close.addTarget(self, action: #selector(done), for: .touchUpInside)

        modeControl.selectedSegmentIndex = KPCRSession.isLoggedIn ? UISegmentedControl.noSegment : (startCreatingAccount ? 1 : 0)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.selectedSegmentTintColor = KPCRStyle.cyan
        modeControl.setTitleTextAttributes([.font: KPCRStyle.rounded(14, weight: .black)], for: .normal)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.alignment = .fill

        status.font = KPCRStyle.rounded(14, weight: .bold)
        status.textColor = KPCRStyle.red
        status.textAlignment = .center
        status.numberOfLines = 0
        status.isHidden = true

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: [close, modeControl, contentStack, status])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            close.heightAnchor.constraint(equalToConstant: 44),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -18),
        ])
    }

    private func render() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        status.isHidden = true
        if KPCRSession.isLoggedIn {
            modeControl.isHidden = true
            renderAccount()
        } else {
            modeControl.isHidden = false
            renderAuthForm(isCreatingAccount: modeControl.selectedSegmentIndex == 1)
        }
    }

    private func renderAuthForm(isCreatingAccount: Bool) {
        let card = KPCRShadowCard()
        card.setContentCompressionResistancePriority(.required, for: .vertical)

        let title = label(isCreatingAccount ? "Create your KPCR account" : "Sign in to KPCR", 24, .black)
        title.textAlignment = .center
        title.numberOfLines = 0
        let email = formField("Email", keyboard: .emailAddress)
        let username = formField("Username")
        username.stack.isHidden = !isCreatingAccount
        let password = formField("Password", isSecure: true)
        emailField = email.input
        usernameField = username.input
        passwordField = password.input
        let primary = authButton(isCreatingAccount ? "Create account" : "Sign In", fill: KPCRStyle.coral)
        primary.addTarget(self, action: #selector(submitAuth), for: .touchUpInside)
        primaryButton = primary

        let forgotPassword = UIButton(type: .system)
        forgotPassword.setTitle("Forgot your password?", for: .normal)
        forgotPassword.titleLabel?.font = KPCRStyle.rounded(16, weight: .black)
        forgotPassword.tintColor = KPCRStyle.ink
        forgotPassword.contentHorizontalAlignment = .right
        forgotPassword.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, email.stack, username.stack, password.stack, forgotPassword, primary])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        card.addContent(stack, insets: UIEdgeInsets(top: 24, left: 18, bottom: 20, right: 18))
        contentStack.addArrangedSubview(card)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: isCreatingAccount ? 460 : 370),
            primary.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func renderAccount() {
        let avatarImage = KPCRSession.hasUploadedAvatar
            ? UIImage(named: "userAvatar")
            : KPCRAvatarAssets.image(index: KPCRSession.avatarIndex)
        let avatarContainer = UIView()
        let avatar = UIImageView(image: avatarImage)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill
        avatar.layer.cornerRadius = 50
        avatar.clipsToBounds = true
        avatar.backgroundColor = .clear
        avatarContainer.addSubview(avatar)
        loadJoinItAvatar(into: avatar)

        let user = KPCRSession.currentUser
        let name = label(user?.displayName ?? user?.username ?? "Pirate Cat Listener", 24, .black)
        name.textAlignment = .center
        let card = KPCRShadowCard()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0
        rows.addArrangedSubview(KPCRAccountRowView(icon: "person.fill", label: "username", value: user?.username ?? "KPCR listener"))
        rows.addArrangedSubview(KPCRAccountRowView(icon: "envelope.fill", label: "email", value: user?.email ?? ""))
        rows.addArrangedSubview(KPCRAccountRowView(icon: "lock.fill", label: "password", value: "Change password") { [weak self] in
            self?.changePasswordTapped()
        })
        rows.addArrangedSubview(KPCRDeleteAccountRowView { [weak self] in
            self?.deleteAccountTapped()
        })
        card.addContent(rows, insets: UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
        let signOut = authButton("Sign out", fill: KPCRStyle.blue)
        signOut.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(avatarContainer)
        contentStack.addArrangedSubview(name)
        contentStack.addArrangedSubview(card)
        contentStack.addArrangedSubview(signOut)
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 112),
            avatar.widthAnchor.constraint(equalToConstant: 100),
            avatar.heightAnchor.constraint(equalToConstant: 100),
            avatar.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            signOut.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func loadJoinItAvatar(into avatar: UIImageView) {
        guard KPCRSession.isLoggedIn else { return }
        Task {
            guard let payload = try? await KPCRAPI.fetchMembership(),
                  let urlString = payload.membership.profileImageURL ?? payload.membership.profileImageUrl,
                  let url = URL(string: urlString),
                  let image = await NetworkService.fetchImage(from: url) else { return }
            await MainActor.run {
                avatar.image = image
                KPCRMembershipCache.store(payload)
            }
        }
    }

    private func formField(_ title: String, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> (stack: UIStackView, input: UITextField) {
        let titleLabel = label(title.uppercased(), 13, .black)
        titleLabel.textColor = KPCRStyle.ink
        let input = field(title, keyboard: keyboard, isSecure: isSecure)
        let stack = UIStackView(arrangedSubviews: [titleLabel, input])
        stack.axis = .vertical
        stack.spacing = 6
        input.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return (stack, input)
    }

    private func field(_ placeholder: String, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.black.withAlphaComponent(0.45)]
        )
        field.keyboardType = keyboard
        field.isSecureTextEntry = isSecure
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.font = KPCRStyle.rounded(17, weight: .medium)
        field.textColor = KPCRStyle.ink
        field.backgroundColor = KPCRStyle.paper
        field.layer.borderWidth = 2
        field.layer.borderColor = KPCRStyle.ink.cgColor
        field.layer.cornerRadius = 10
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        return field
    }

    private func authButton(_ title: String, fill: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = KPCRStyle.rounded(18, weight: .black)
        button.tintColor = .white
        button.backgroundColor = fill
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 2
        button.layer.borderColor = KPCRStyle.ink.cgColor
        return button
    }

    @objc private func modeChanged() { render() }
    @objc private func submitAuth() {
        let isCreatingAccount = modeControl.selectedSegmentIndex == 1
        let email = emailField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let username = usernameField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField?.text ?? ""

        guard email.contains("@"), password.count >= 8 else {
            status.text = "Enter a valid email and a password with at least 8 characters."
            status.isHidden = false
            return
        }

        if isCreatingAccount && username.isEmpty {
            status.text = "Choose a username for your KPCR account."
            status.isHidden = false
            return
        }

        primaryButton?.isEnabled = false
        primaryButton?.alpha = 0.65
        status.text = isCreatingAccount ? "Creating your account..." : "Signing in..."
        status.textColor = KPCRStyle.ink
        status.isHidden = false

        Task { [weak self] in
            do {
                let response = isCreatingAccount
                    ? try await KPCRAPI.signUp(email: email, username: username, password: password)
                    : try await KPCRAPI.signIn(email: email, password: password)
                await MainActor.run {
                    KPCRSession.signIn(token: response.token, user: response.user, assignNewAvatar: isCreatingAccount)
                    self?.status.textColor = KPCRStyle.green
                    self?.status.text = "Signed in."
                    self?.primaryButton?.isEnabled = true
                    self?.primaryButton?.alpha = 1
                    self?.render()
                }
            } catch {
                await MainActor.run {
                    self?.status.textColor = KPCRStyle.red
                    self?.status.text = error.localizedDescription
                    self?.status.isHidden = false
                    self?.primaryButton?.isEnabled = true
                    self?.primaryButton?.alpha = 1
                }
            }
        }
    }

    @objc private func forgotPasswordTapped() {
        let email = emailField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let alert = UIAlertController(title: "Reset password", message: "Enter your KPCR account email and we'll send a reset link.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Email"
            field.keyboardType = .emailAddress
            field.autocapitalizationType = .none
            field.text = email
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send link", style: .default) { [weak self, weak alert] _ in
            let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            Task { [weak self] in
                do {
                    try await KPCRAPI.requestPasswordReset(email: value)
                    await MainActor.run {
                        self?.status.textColor = KPCRStyle.green
                        self?.status.text = "If that email has a KPCR account, a reset link is on its way."
                        self?.status.isHidden = false
                    }
                } catch {
                    await MainActor.run {
                        self?.status.textColor = KPCRStyle.red
                        self?.status.text = "Could not request a reset link. Try again."
                        self?.status.isHidden = false
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func changePasswordTapped() {
        let alert = UIAlertController(title: "Change password", message: "Enter your current password and choose a new one.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Current password"
            field.isSecureTextEntry = true
        }
        alert.addTextField { field in
            field.placeholder = "New password"
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self, weak alert] _ in
            let current = alert?.textFields?.first?.text ?? ""
            let new = alert?.textFields?.dropFirst().first?.text ?? ""
            Task { [weak self] in
                do {
                    try await KPCRAPI.changePassword(currentPassword: current, newPassword: new)
                    await MainActor.run {
                        self?.status.textColor = KPCRStyle.green
                        self?.status.text = "Password updated."
                        self?.status.isHidden = false
                    }
                } catch {
                    await MainActor.run {
                        self?.status.textColor = KPCRStyle.red
                        self?.status.text = error.localizedDescription
                        self?.status.isHidden = false
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func deleteAccountTapped() {
        let alert = UIAlertController(title: "Delete account?", message: "This permanently deletes your KPCR app account, sign-in, and saved favorites — it cannot be undone. If you have a paid Signal Society membership through Join It, that's billed and managed separately and is not affected; cancel it directly with Join It. Enter your password to confirm.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Password"
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self, weak alert] _ in
            let password = alert?.textFields?.first?.text ?? ""
            Task { [weak self] in
                do {
                    try await KPCRAPI.deleteAccount(password: password)
                    await MainActor.run {
                        KPCRSession.signOut()
                        self?.status.textColor = KPCRStyle.green
                        self?.status.text = "Account deleted."
                        self?.status.isHidden = false
                        self?.render()
                    }
                } catch {
                    await MainActor.run {
                        self?.status.textColor = KPCRStyle.red
                        self?.status.text = error.localizedDescription
                        self?.status.isHidden = false
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func signOutTapped() {
        KPCRSession.signOut()
        modeControl.selectedSegmentIndex = 0
        render()
    }
    @objc private func done() { dismiss(animated: true) }
}

private final class KPCRAccountRowView: UIView {
    private let action: (() -> Void)?

    init(icon: String, label: String, value: String, destructive: Bool = false, action: (() -> Void)? = nil) {
        self.action = action
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        if action != nil {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = destructive ? KPCRStyle.red : KPCRStyle.blue
        symbol.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = label
        title.font = KPCRStyle.rounded(18, weight: destructive ? .medium : .regular)
        title.textColor = destructive ? KPCRStyle.red : UIColor.black.withAlphaComponent(0.72)
        let detail = UILabel()
        detail.text = value
        detail.font = KPCRStyle.rounded(18, weight: .black)
        detail.textColor = KPCRStyle.ink
        detail.textAlignment = .right
        detail.lineBreakMode = .byTruncatingMiddle
        detail.minimumScaleFactor = 0.78
        detail.adjustsFontSizeToFitWidth = true
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.black.withAlphaComponent(0.45)
        let row = UIStackView(arrangedSubviews: [symbol, title, detail, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 24),
            symbol.heightAnchor.constraint(equalToConstant: 24),
            chevron.widthAnchor.constraint(equalToConstant: 16),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
        detail.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @objc private func tapped() {
        action?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class KPCRDeleteAccountRowView: UIView {
    private let action: (() -> Void)?

    init(action: (() -> Void)? = nil) {
        self.action = action
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let symbol = UIImageView(image: UIImage(systemName: "trash.fill"))
        symbol.tintColor = KPCRStyle.red
        symbol.contentMode = .scaleAspectFit
        let title = label("Delete account", 18, .medium, KPCRStyle.red)
        let row = UIStackView(arrangedSubviews: [symbol, title])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 22),
            symbol.heightAnchor.constraint(equalToConstant: 22),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    @objc private func tapped() {
        action?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private func label(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor = KPCRStyle.ink) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = KPCRStyle.rounded(size, weight: weight)
    label.textColor = color
    label.numberOfLines = 1
    return label
}

private func icon(_ name: String, _ color: UIColor = KPCRStyle.ink) -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)), for: .normal)
    button.tintColor = color
    button.widthAnchor.constraint(equalToConstant: 34).isActive = true
    button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    return button
}

private func showSignInRequiredMessage() {
    showToast("  Sign in to save favorites.  ")
}

private func showToast(_ message: String) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
          let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

    let toast = UILabel()
    toast.text = message
    toast.font = KPCRStyle.rounded(15, weight: .bold)
    toast.textColor = .white
    toast.textAlignment = .center
    toast.backgroundColor = KPCRStyle.ink.withAlphaComponent(0.94)
    toast.layer.cornerRadius = 18
    toast.clipsToBounds = true
    toast.alpha = 0
    toast.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(toast)

    NSLayoutConstraint.activate([
        toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
        toast.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -118),
        toast.heightAnchor.constraint(equalToConstant: 38),
        toast.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 20),
        toast.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -20),
    ])

    UIView.animate(withDuration: 0.16) {
        toast.alpha = 1
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
        UIView.animate(withDuration: 0.2, animations: {
            toast.alpha = 0
        }) { _ in
            toast.removeFromSuperview()
        }
    }
}

private extension DateFormatter {
    static let rfc822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}
