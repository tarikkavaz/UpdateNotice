import Foundation

/// Every visible string. The package holds no localization: an app starts from the English
/// defaults and replaces each field with its own localized text.
public struct UpdateStrings: Sendable {
    // Update window
    public var windowTitle: @Sendable (_ appName: String, _ version: String) -> String = { "\($0) \($1) is available" }
    public var currentVersion: @Sendable (_ version: String) -> String = { "You have \($0)." }
    public var copyCommand = "Copy update command"
    public var copyAndOpenTerminal = "Copy and open Terminal"
    public var copied = "Copied. Paste it in Terminal."
    public var remindLater = "Remind me later"
    public var skipVersion = "Skip this version"

    // Settings section
    public var sectionTitle = "Updates"
    public var automaticChecks = "Check for updates automatically"
    public var automaticChecksHint: @Sendable (_ host: String) -> String = {
        "The app asks \($0) for the latest version number. Nothing else is sent."
    }
    public var frequency = "Check"
    public var everyLaunch = "Every launch"
    public var daily = "Daily"
    public var weekly = "Weekly"
    public var checkNow = "Check now"
    public var checking = "Checking..."
    public var upToDate = "You are up to date."
    public var availableShort: @Sendable (_ version: String) -> String = { "Version \($0) is available." }
    public var couldNotCheck = "Could not check for updates."
    public var lastChecked: @Sendable (_ when: String) -> String = { "Last checked: \($0)" }
    public var never = "Never"
    public var skippedVersion: @Sendable (_ version: String) -> String = { "Skipped version: \($0)" }
    public var resetSkipped = "Reset"

    // Menu bar entry
    public var menuItem = "Update available"

    public init() {}
}
