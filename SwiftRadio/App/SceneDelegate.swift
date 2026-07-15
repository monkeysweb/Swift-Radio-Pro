//
//  SceneDelegate.swift
//  Swift Radio
//
//  Created by Fethi El Hassasna on 1/25/25.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit

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
        coordinator = MainCoordinator(navigationController: UINavigationController())
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = coordinator?.navigationController
        window?.makeKeyAndVisible()
        
        coordinator?.start()
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

    static func rounded(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}

private enum KPCRSession {
    static let isLoggedIn = false
    static let hasUploadedAvatar = false
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
        let title = clean(player.currentMetadata?.trackName)
        let artist = clean(player.currentMetadata?.artistName)
        guard title != currentTitle || artist != currentArtist else { return }
        currentTitle = title
        currentArtist = artist
        currentArtwork = artwork(for: title, artist: artist)
        if let title, let artist {
            addRecent(title: title, artist: artist)
            scheduleArtworkFetch(title: title, artist: artist)
        }
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
    #if DEBUG
    static let base = "http://127.0.0.1:4321"
    #else
    static let base = "https://kpcr.org"
    #endif

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
        for controller in viewControllers ?? [] {
            controller.additionalSafeAreaInsets.bottom = 76
        }
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
        present(SFSafariViewController(url: url), animated: true)
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

    func presentProfile() {
        let profile = KPCRProfileViewController()
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

    override init(frame: CGRect) {
        logoSize = logoBadge.widthAnchor.constraint(equalToConstant: 96)
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        backgroundColor = KPCRStyle.paper

        let menu = iconButton("line.3.horizontal")
        menu.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)

        let logo = UIImageView(image: UIImage(named: "logo"))
        logo.contentMode = .scaleAspectFit
        logoBadge.backgroundColor = KPCRStyle.cyan
        logoBadge.layer.borderWidth = 2
        logoBadge.layer.borderColor = KPCRStyle.ink.cgColor
        logoBadge.layer.cornerRadius = 48
        logoBadge.clipsToBounds = true
        logoBadge.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(logoTapped)))

        let accountButton = KPCRSession.isLoggedIn ? avatarButton() : signInButton()
        accountButton.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)

        logo.translatesAutoresizingMaskIntoConstraints = false
        logoBadge.translatesAutoresizingMaskIntoConstraints = false
        logoBadge.addSubview(logo)

        [menu, logoBadge, accountButton].forEach {
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

            accountButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            accountButton.centerYAnchor.constraint(equalTo: menu.centerYAnchor),
            accountButton.widthAnchor.constraint(equalToConstant: KPCRSession.isLoggedIn ? 46 : 74),
            accountButton.heightAnchor.constraint(equalToConstant: KPCRSession.isLoggedIn ? 46 : 38),
        ])
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

    private func avatarButton() -> UIButton {
        let button = UIButton(type: .system)
        let imageName = KPCRSession.hasUploadedAvatar ? "userAvatar" : "stationImage"
        button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.layer.cornerRadius = 23
        button.layer.borderWidth = 2
        button.layer.borderColor = KPCRStyle.ink.cgColor
        button.backgroundColor = KPCRStyle.cyan
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
        if let liveShow = KPCRNowPlayingCenter.shared.liveShowForDisplay {
            recentHost.addArrangedSubview(KPCRShowCardView(show: liveShow) { [weak self] in
                self?.showDetail(liveShow)
            })
        }
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
        daysStack.spacing = 6
        listStack.axis = .vertical
        listStack.spacing = 14
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
            button.titleLabel?.font = KPCRStyle.rounded(18, weight: .black)
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
            for item in giveaways {
                contentStack.addArrangedSubview(KPCRGiveawayCardView(item: item) { [weak self] in
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
        subscribe.setTitle("♡ Subscribe", for: .normal)
        subscribe.titleLabel?.font = KPCRStyle.rounded(22, weight: .regular)
        subscribe.tintColor = KPCRStyle.red
        subscribe.heightAnchor.constraint(equalToConstant: 60).isActive = true
        subscribe.addAction(UIAction { _ in showSignInRequiredMessage() }, for: .touchUpInside)

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

private final class KPCRMyPCRViewController: KPCRBaseViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.addArrangedSubview(sectionTitle("My KPCR"))
        contentStack.addArrangedSubview(KPCRLoginCardView { [weak self] in
            self?.presentProfile()
        })
        contentStack.addArrangedSubview(KPCREmptyCardView(message: "Liked shows, liked songs, and Signal Society member options will appear here after account setup."))
        contentStack.addArrangedSubview(KPCRMenuCardView(title: "Signal Society", rows: ["Membership status", "Double giveaway entries", "Member perks", "Content coming soon"]))
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
    private let play = UIButton(type: .system)
    private let player = FRadioPlayer.shared
    private var notificationToken: NSObjectProtocol?

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

        let heart = UIButton(type: .system)
        heart.setImage(UIImage(systemName: "heart"), for: .normal)
        heart.tintColor = KPCRStyle.ink
        heart.addAction(UIAction { _ in showSignInRequiredMessage() }, for: .touchUpInside)

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
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let notificationToken { NotificationCenter.default.removeObserver(notificationToken) }
    }

    func refresh() {
        title.text = KPCRNowPlayingCenter.shared.displayTitle ?? player.currentMetadata?.trackName ?? StationsManager.shared.currentStation?.name ?? "KPCR 92.9FM"
        subtitle.text = KPCRNowPlayingCenter.shared.displayArtist ?? player.currentMetadata?.artistName ?? StationsManager.shared.currentStation?.desc ?? "Pirate Cat Radio"
        artView.image = KPCRNowPlayingCenter.shared.displayArtwork
        let icon = player.isPlaying ? "stop.fill" : "play.fill"
        play.setImage(UIImage(systemName: icon), for: .normal)
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
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let image = KPCRSquareImageView(urlString: show.imageUrl)
        let title = label(show.title, 21, .black)
        let host = label(show.host, 17, .regular)
        let dayPrefix = show.day.map { String($0.prefix(3)) + " " } ?? ""
        let time = label((dayPrefix + show.time).replacingOccurrences(of: ":00", with: ""), 16, .bold, KPCRStyle.red)
        let text = UIStackView(arrangedSubviews: [title, host, time])
        text.axis = .vertical
        text.spacing = 7
        title.numberOfLines = 1
        title.lineBreakMode = .byTruncatingTail
        host.numberOfLines = 1
        host.lineBreakMode = .byTruncatingTail
        time.numberOfLines = 1
        time.lineBreakMode = .byTruncatingTail
        let share = icon("square.and.arrow.up")
        let heart = icon("heart")
        heart.addAction(UIAction { _ in showSignInRequiredMessage() }, for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [share, heart])
        actions.axis = .horizontal
        actions.spacing = 14
        actions.alignment = .center
        let row = UIStackView(arrangedSubviews: [image, text, actions])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14
        addContent(row, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        image.widthAnchor.constraint(equalToConstant: 86).isActive = true
        image.heightAnchor.constraint(equalToConstant: 86).isActive = true
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        actions.setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        onTap?()
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
        if let imageUrl = track.imageUrl, let url = URL(string: imageUrl) {
            Task {
                let fetched = await NetworkService.fetchImage(from: url)
                await MainActor.run { if let fetched { image.image = fetched } }
            }
        } else if let cached = KPCRNowPlayingCenter.shared.artwork(for: track.title, artist: track.artist) {
            image.image = cached
        } else {
            KPCRNowPlayingCenter.shared.fetchArtwork(for: track)
            _ = NotificationCenter.default.addObserver(forName: .kpcrNowPlayingChanged, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    if image.image == nil, let cached = KPCRNowPlayingCenter.shared.artwork(for: track.title, artist: track.artist) {
                        image.image = cached
                    }
                }
            }
        }
        let gradient = UIView()
        gradient.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        let title = label(track.title, 17, .black, .white)
        let artist = label(track.artist, 14, .bold, .white)
        let heart = icon("heart", .white)
        heart.addAction(UIAction { _ in showSignInRequiredMessage() }, for: .touchUpInside)
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
        artwork.image = KPCRNowPlayingCenter.shared.displayArtwork
    }
}

private final class KPCRGiveawayCardView: KPCRShadowCard {
    private let onTap: (() -> Void)?

    init(item: KPCRGiveaway, onTap: (() -> Void)? = nil) {
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = KPCRStyle.green
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let title = label(item.title, 20, .black)
        let venue = label([item.venue, item.city].compactMap { $0 }.joined(separator: " · "), 16, .regular)
        let enter = label("Enter to win ->", 16, .bold, KPCRStyle.ink)
        let image = KPCRSquareImageView(urlString: item.imageUrl)
        let stack = UIStackView(arrangedSubviews: [title, venue, enter])
        stack.axis = .vertical
        stack.spacing = 8
        let row = UIStackView(arrangedSubviews: [image, stack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        addContent(row, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        image.widthAnchor.constraint(equalToConstant: 86).isActive = true
        image.heightAnchor.constraint(equalToConstant: 86).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        onTap?()
    }
}

private final class KPCRLoginCardView: KPCRShadowCard {
    private let onSignIn: (() -> Void)?

    init(onSignIn: (() -> Void)? = nil) {
        self.onSignIn = onSignIn
        super.init(frame: .zero)
        backgroundColor = KPCRStyle.ice
        let image = UIImageView(image: UIImage(named: "stationImage"))
        image.contentMode = .scaleAspectFit
        let signIn = UIButton(type: .system)
        signIn.setTitle("Sign In", for: .normal)
        signIn.titleLabel?.font = KPCRStyle.rounded(18, weight: .black)
        signIn.tintColor = .white
        signIn.backgroundColor = KPCRStyle.coral
        signIn.layer.cornerRadius = 10
        signIn.layer.borderWidth = 2
        signIn.layer.borderColor = KPCRStyle.ink.cgColor
        signIn.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        let signUp = label("Don't have an account? Sign up", 19, .medium)
        signUp.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [image, signIn, signUp])
        stack.axis = .vertical
        stack.spacing = 18
        addContent(stack, insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
        image.heightAnchor.constraint(equalToConstant: 220).isActive = true
        signIn.heightAnchor.constraint(equalToConstant: 52).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func signInTapped() {
        onSignIn?()
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

        modeControl.selectedSegmentIndex = KPCRSession.isLoggedIn ? UISegmentedControl.noSegment : 0
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

        let avatar = UIImageView(image: UIImage(named: "stationImage"))
        avatar.contentMode = .scaleAspectFit
        avatar.layer.cornerRadius = 50
        avatar.clipsToBounds = true
        avatar.backgroundColor = KPCRStyle.cyan

        let title = label(isCreatingAccount ? "Create your KPCR account" : "Sign in to KPCR", 24, .black)
        title.textAlignment = .center
        title.numberOfLines = 0
        let email = fieldGroup("Email", keyboard: .emailAddress)
        let username = fieldGroup("Username")
        username.isHidden = !isCreatingAccount
        let password = fieldGroup("Password", isSecure: true)
        let primary = authButton(isCreatingAccount ? "Create account" : "Sign In", fill: KPCRStyle.coral)
        primary.addTarget(self, action: #selector(authUnavailable), for: .touchUpInside)
        let apple = authButton("Sign in with Apple", fill: KPCRStyle.ink)
        apple.addTarget(self, action: #selector(authUnavailable), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [avatar, title, email, username, password, primary, apple])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        card.addContent(stack, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
        contentStack.addArrangedSubview(card)
        NSLayoutConstraint.activate([
            avatar.heightAnchor.constraint(equalToConstant: 100),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: isCreatingAccount ? 520 : 440),
            primary.heightAnchor.constraint(equalToConstant: 50),
            apple.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func renderAccount() {
        let avatar = UIImageView(image: UIImage(named: KPCRSession.hasUploadedAvatar ? "userAvatar" : "stationImage"))
        avatar.contentMode = .scaleAspectFit
        avatar.layer.cornerRadius = 50
        avatar.clipsToBounds = true
        avatar.backgroundColor = KPCRStyle.cyan

        let name = label("Pirate Cat Listener", 24, .black)
        name.textAlignment = .center
        let card = KPCRShadowCard()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0
        rows.addArrangedSubview(KPCRAccountRowView(icon: "person.fill", label: "username", value: "PirateCat"))
        rows.addArrangedSubview(KPCRAccountRowView(icon: "envelope.fill", label: "email", value: "listener@kpcr.org"))
        rows.addArrangedSubview(KPCRAccountRowView(icon: "lock.fill", label: "password", value: "Change password"))
        rows.addArrangedSubview(KPCRAccountRowView(icon: "bell.slash.fill", label: "reset", value: "Reset notification count"))
        rows.addArrangedSubview(KPCRAccountRowView(icon: "trash.fill", label: "Delete account", value: "", destructive: true))
        card.addContent(rows, insets: UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
        let signOut = authButton("Sign out", fill: KPCRStyle.blue)
        signOut.addTarget(self, action: #selector(authUnavailable), for: .touchUpInside)
        contentStack.addArrangedSubview(avatar)
        contentStack.addArrangedSubview(name)
        contentStack.addArrangedSubview(card)
        contentStack.addArrangedSubview(signOut)
        NSLayoutConstraint.activate([
            avatar.heightAnchor.constraint(equalToConstant: 100),
            signOut.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func fieldGroup(_ title: String, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> UIStackView {
        let titleLabel = label(title.uppercased(), 13, .black)
        titleLabel.textColor = KPCRStyle.ink
        let input = field(title, keyboard: keyboard, isSecure: isSecure)
        let stack = UIStackView(arrangedSubviews: [titleLabel, input])
        stack.axis = .vertical
        stack.spacing = 6
        input.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return stack
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
    @objc private func authUnavailable() {
        status.text = "Account backend is not connected yet."
        status.isHidden = false
    }
    @objc private func done() { dismiss(animated: true) }
}

private final class KPCRAccountRowView: UIView {
    init(icon: String, label: String, value: String, destructive: Bool = false) {
        super.init(frame: .zero)
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
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
          let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

    let toast = UILabel()
    toast.text = "  Sign in to save favorites.  "
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
