# UpdateNotice

A small Swift package that tells a Homebrew-distributed macOS app when a new version exists. It never downloads or installs anything. The update window offers the command `brew update && brew upgrade --cask <cask>`, to copy or to paste into Terminal.

## How it works

The release script uploads `latest.json` next to the zip, for example `https://casks.kavaz.org/<app>/latest.json`:

```json
{"version": "2.0.5", "notes": "One short line."}
```

The app fetches it on launch (no more often than the chosen frequency), compares it with `CFBundleShortVersionString`, and shows the update window when the remote version is newer and not skipped.

## Targets

- `UpdateNotice`: logic (`Version`, `UpdateFetching`, `UpdatePreferences`, `UpdateChecker`, `UpdateConfiguration`). No UI.
- `UpdateNoticeUI`: SwiftUI and AppKit (`UpdateWindowController`, `UpdateSettingsSection`, `UpdateStrings`).

## Use in an app

```swift
let preferences = UpdatePreferences()
let checker = UpdateChecker(
    configuration: UpdateConfiguration(
        appName: "Correctify",
        caskName: "correctify",
        feedURL: URL(string: "https://casks.kavaz.org/correctify/latest.json")!,
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    ),
    preferences: preferences
)
let windowController = UpdateWindowController(checker: checker, strings: strings)  // keep it alive
Task { await checker.checkOnLaunch() }
```

- Settings: put `UpdateSettingsSection(checker: checker, strings: strings)` inside a `Form`.
- Menu bar entry: show it while `checker.available != nil`, and call `checker.showAvailable()` when it is chosen.
- Strings: `UpdateStrings()` holds English defaults. Assign each field your localized text.

## Behavior

- Automatic checks are on by default, fail silently, and make no request at all while the toggle is off.
- "Check now" ignores the frequency and the skipped version, works while automatic checks are off, and reports failures.
- The request is a plain GET on an ephemeral session: no cookies, no cache, no custom headers.

## Tests

`swift test`
