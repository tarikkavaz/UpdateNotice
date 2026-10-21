import AppKit

/// What the update window can do to the system. A protocol so tests can fake it.
@MainActor
public protocol UpdateActions {
    func copyToClipboard(_ text: String)
    func openTerminal()
}

public struct SystemUpdateActions: UpdateActions {
    public init() {}

    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Opens Terminal.app only. The command is never run: AppleScript `do script` would run it
    /// at once and need an Automation permission.
    public func openTerminal() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
