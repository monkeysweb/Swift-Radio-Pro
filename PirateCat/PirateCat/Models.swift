import Foundation

struct PCUser: Codable, Equatable {
    let id: String
    let displayName: String
}

struct PCFriend: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let addedAt: String
}

struct PCAuthResponse: Codable {
    let token: String
    let user: PCUser
}

struct PCErrorResponse: Codable {
    let error: String?
    let retryAfter: Int?
}
