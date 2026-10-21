import Foundation

public enum UpdateFrequency: String, CaseIterable, Sendable {
    case everyLaunch
    case daily
    case weekly

    /// Minimum time between automatic checks. Nil means every launch checks.
    public var interval: TimeInterval? {
        switch self {
        case .everyLaunch: nil
        case .daily: 24 * 60 * 60
        case .weekly: 7 * 24 * 60 * 60
        }
    }
}

/// The update settings, kept in UserDefaults under keys with an `update` prefix.
@MainActor
public final class UpdatePreferences: ObservableObject {
    private enum Key {
        static let automatic = "updateAutomaticChecks"
        static let frequency = "updateFrequency"
        static let lastChecked = "updateLastChecked"
        static let skipped = "updateSkippedVersion"
        static let latestVersion = "updateLatestVersion"
        static let latestNotes = "updateLatestNotes"
    }

    private let defaults: UserDefaults

    /// Off means no request at all, except from "Check now".
    @Published public var automaticChecks: Bool { didSet { defaults.set(automaticChecks, forKey: Key.automatic) } }
    @Published public var frequency: UpdateFrequency { didSet { defaults.set(frequency.rawValue, forKey: Key.frequency) } }
    @Published public internal(set) var lastChecked: Date? { didSet { defaults.set(lastChecked, forKey: Key.lastChecked) } }
    @Published public internal(set) var skippedVersion: String? { didSet { defaults.set(skippedVersion, forKey: Key.skipped) } }
    /// The newest version the last successful check saw. Lets the menu entry survive a relaunch.
    @Published public internal(set) var latestVersion: String? { didSet { defaults.set(latestVersion, forKey: Key.latestVersion) } }
    @Published public internal(set) var latestNotes: String? { didSet { defaults.set(latestNotes, forKey: Key.latestNotes) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        automaticChecks = defaults.object(forKey: Key.automatic) as? Bool ?? true
        frequency = defaults.string(forKey: Key.frequency).flatMap(UpdateFrequency.init(rawValue:)) ?? .daily
        lastChecked = defaults.object(forKey: Key.lastChecked) as? Date
        skippedVersion = defaults.string(forKey: Key.skipped)
        latestVersion = defaults.string(forKey: Key.latestVersion)
        latestNotes = defaults.string(forKey: Key.latestNotes)
    }
}
