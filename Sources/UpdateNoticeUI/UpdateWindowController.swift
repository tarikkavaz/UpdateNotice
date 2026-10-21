import AppKit
import Combine
import SwiftUI
import UpdateNotice

/// Shows the update window whenever `checker.presented` is set, and clears it when the window
/// closes. Create one per app and keep it alive.
@MainActor
public final class UpdateWindowController: NSObject, NSWindowDelegate {
    private let checker: UpdateChecker
    /// Replace it when the app language changes. A window that is open keeps its old text until
    /// it is shown again.
    public var strings: UpdateStrings
    private let actions: any UpdateActions
    private var window: NSWindow?
    private var shownVersion: String?
    private var subscription: AnyCancellable?

    public init(checker: UpdateChecker, strings: UpdateStrings = UpdateStrings(), actions: any UpdateActions = SystemUpdateActions()) {
        self.checker = checker
        self.strings = strings
        self.actions = actions
        super.init()
        subscription = checker.$presented
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                MainActor.assumeIsolated { self?.present(update) }
            }
    }

    private func present(_ update: AvailableUpdate?) {
        guard let update else {
            close()
            return
        }
        if let window, shownVersion == update.version {
            bringToFront(window)
            return
        }
        let model = UpdatePromptModel(update: update, checker: checker, actions: actions)
        let host = NSHostingController(rootView: UpdateView(model: model, strings: strings))
        let window = self.window ?? NSWindow()
        window.styleMask = [.titled, .closable]
        window.title = strings.windowTitle(checker.configuration.appName, update.version)
        window.contentViewController = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        shownVersion = update.version
        bringToFront(window)
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        shownVersion = nil
        guard let window, window.isVisible else { return }
        window.delegate = nil
        window.close()
        window.delegate = self
    }

    /// The red close button counts as "remind me later".
    public func windowWillClose(_ notification: Notification) {
        shownVersion = nil
        if checker.presented != nil { checker.remindLater() }
    }
}
