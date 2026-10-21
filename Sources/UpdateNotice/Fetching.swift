import Foundation

/// The content of `latest.json`: `{"version": "2.0.5", "notes": "one short line"}`.
public struct LatestRelease: Decodable, Equatable, Sendable {
    public var version: String
    public var notes: String?

    public init(version: String, notes: String? = nil) {
        self.version = version
        self.notes = notes
    }
}

public enum UpdateError: Error, Equatable, Sendable {
    case badStatus(Int)
    case invalidResponse
}

/// Fetches the version file. A protocol so tests can fake it.
public protocol UpdateFetching: Sendable {
    func fetchLatest(from url: URL) async throws -> LatestRelease
}

/// A plain GET with a short timeout. Ephemeral session: no cookies, no cache, no stored
/// credentials, and no custom headers. The request carries nothing about the user.
public struct URLSessionUpdateFetcher: UpdateFetching {
    private let session: URLSession

    public init(timeout: TimeInterval = 5) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    public func fetchLatest(from url: URL) async throws -> LatestRelease {
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
        guard http.statusCode == 200 else { throw UpdateError.badStatus(http.statusCode) }
        return try JSONDecoder().decode(LatestRelease.self, from: data)
    }
}
