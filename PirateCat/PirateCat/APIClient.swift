import Foundation

enum APIError: LocalizedError {
    case offline
    case server(String)
    case rateLimited(retryAfter: Int)
    case unauthorized
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Check your connection and try again."
        case .server(let code):
            return APIError.message(for: code)
        case .rateLimited(let retryAfter):
            return "Slow down — try again in \(max(1, retryAfter))s."
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .decoding:
            return "Something went wrong talking to Pirate Cat. Try again."
        }
    }

    private static func message(for code: String) -> String {
        switch code {
        case "display_name_taken": return "That name is already taken."
        case "valid_display_name_required": return "Names must be 2-24 characters (letters, numbers, spaces, - _ .)."
        case "valid_password_required": return "Password must be 8-256 characters."
        case "invalid_credentials": return "Incorrect name or password."
        case "user_not_found": return "No one goes by that name."
        case "cannot_add_self": return "You can't add yourself."
        case "not_a_friend": return "Add them first before sending a Pirate Cat."
        default: return "Something went wrong (\(code))."
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared

    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authorized: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: Config.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }

        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode == 429 {
            let retryAfter = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "5") ?? 5
            throw APIError.rateLimited(retryAfter: retryAfter)
        }
        if http.statusCode >= 400 {
            let decoded = try? JSONDecoder().decode(PCErrorResponse.self, from: data)
            throw APIError.server(decoded?.error ?? "request_failed")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    struct OKResponse: Decodable { let ok: Bool }
    struct FriendsResponse: Decodable { let friends: [PCFriend] }
    struct AddFriendResponse: Decodable { let friend: PCUser }
    struct YoResponse: Decodable { let ok: Bool; let delivered: Bool }

    func signup(displayName: String, password: String) async throws -> PCAuthResponse {
        try await request("/api/piratecat/auth/signup", method: "POST", body: ["displayName": displayName, "password": password], authorized: false)
    }

    func signin(displayName: String, password: String) async throws -> PCAuthResponse {
        try await request("/api/piratecat/auth/signin", method: "POST", body: ["displayName": displayName, "password": password], authorized: false)
    }

    func fetchFriends() async throws -> [PCFriend] {
        (try await request("/api/piratecat/friends", method: "GET") as FriendsResponse).friends
    }

    func addFriend(displayName: String) async throws -> PCUser {
        (try await request("/api/piratecat/friends", method: "POST", body: ["displayName": displayName]) as AddFriendResponse).friend
    }

    func registerDevice(token deviceToken: String, environment: String) async throws {
        _ = try await request("/api/piratecat/devices", method: "POST", body: ["deviceToken": deviceToken, "environment": environment]) as OKResponse
    }

    @discardableResult
    func sendYo(friendId: String) async throws -> Bool {
        (try await request("/api/piratecat/yo", method: "POST", body: ["friendId": friendId]) as YoResponse).delivered
    }
}
