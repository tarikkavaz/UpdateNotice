import Foundation

/// What an app supplies: its name, its cask and where the version file lives.
public struct UpdateConfiguration: Sendable {
    public var appName: String
    public var caskName: String
    public var feedURL: URL
    /// `CFBundleShortVersionString` of the running app.
    public var currentVersion: String

    public init(appName: String, caskName: String, feedURL: URL, currentVersion: String) {
        self.appName = appName
        self.caskName = caskName
        self.feedURL = feedURL
        self.currentVersion = currentVersion
    }

    /// The command the update window offers. The app never runs it.
    public var brewCommand: String { "brew update && brew upgrade --cask \(caskName)" }
}

public struct AvailableUpdate: Equatable, Identifiable, Sendable {
    public var version: String
    public var notes: String?
    public var id: String { version }

    public init(version: String, notes: String? = nil) {
        self.version = version
        self.notes = notes
    }
}

public enum ManualCheckResult: Equatable, Sendable {
    case upToDate
    case available(AvailableUpdate)
    case failed
}

/// Decides when to look for a new version, remembers the answer, and tells the UI.
///
/// Automatic checks fail silently. A manual check reports its failure, ignores the frequency
/// and the skipped version, and works while automatic checks are off.
@MainActor
public final class UpdateChecker: ObservableObject {
    public let configuration: UpdateConfiguration
    public let preferences: UpdatePreferences
    private let fetcher: any UpdateFetching
    private let now: @Sendable () -> Date

    /// A newer version that is not skipped. Drives the menu bar entry.
    @Published public private(set) var available: AvailableUpdate?
    /// Set when the update window should be on screen, cleared when it is dismissed.
    @Published public var presented: AvailableUpdate?

    public init(
        configuration: UpdateConfiguration,
        preferences: UpdatePreferences,
        fetcher: any UpdateFetching = URLSessionUpdateFetcher(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.preferences = preferences
        self.fetcher = fetcher
        self.now = now
        recompute()
    }

    /// Call once at launch. Does nothing while automatic checks are off or the last check is
    /// still inside the frequency interval.
    public func checkOnLaunch() async {
        guard preferences.automaticChecks else { return }
        if let last = preferences.lastChecked, let interval = preferences.frequency.interval,
           now().timeIntervalSince(last) < interval { return }
        guard let release = try? await fetch() else { return }
        record(release)
        if let available { presented = available }
    }

    /// "Check now": always asks, and says what happened.
    @discardableResult
    public func checkNow() async -> ManualCheckResult {
        guard let release = try? await fetch() else { return .failed }
        record(release)
        guard isNewer(release.version) else { return .upToDate }
        let update = AvailableUpdate(version: release.version, notes: release.notes)
        presented = update
        return .available(update)
    }

    /// Menu bar entry: bring the window back while an update is known.
    public func showAvailable() {
        if let available { presented = available }
    }

    public func remindLater() { presented = nil }

    public func skip(_ update: AvailableUpdate) {
        preferences.skippedVersion = update.version
        presented = nil
        recompute()
    }

    public func resetSkipped() {
        preferences.skippedVersion = nil
        recompute()
    }

    private func fetch() async throws -> LatestRelease {
        let release = try await fetcher.fetchLatest(from: configuration.feedURL)
        guard Version(release.version) != nil else { throw UpdateError.invalidResponse }
        return release
    }

    private func record(_ release: LatestRelease) {
        preferences.lastChecked = now()
        preferences.latestVersion = release.version
        preferences.latestNotes = release.notes
        recompute()
    }

    private func isNewer(_ version: String) -> Bool {
        guard let remote = Version(version), let current = Version(configuration.currentVersion) else { return false }
        return remote > current
    }

    private func recompute() {
        guard let version = preferences.latestVersion, isNewer(version), version != preferences.skippedVersion else {
            available = nil
            return
        }
        available = AvailableUpdate(version: version, notes: preferences.latestNotes)
    }
}
