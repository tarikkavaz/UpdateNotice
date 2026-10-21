import Foundation
import UpdateNotice

/// The buttons of the update window.
@MainActor
public final class UpdatePromptModel: ObservableObject {
    public let update: AvailableUpdate
    public let checker: UpdateChecker
    private let actions: any UpdateActions

    /// True after Copy, so the window can say the command is on the clipboard.
    @Published public private(set) var didCopy = false

    public init(update: AvailableUpdate, checker: UpdateChecker, actions: any UpdateActions) {
        self.update = update
        self.checker = checker
        self.actions = actions
    }

    public var currentVersion: String { checker.configuration.currentVersion }
    public var appName: String { checker.configuration.appName }

    public func copyCommand() {
        actions.copyToClipboard(checker.configuration.brewCommand)
        didCopy = true
    }

    /// Puts the command on the clipboard and opens Terminal. The user pastes and presses Return.
    public func copyAndOpenTerminal() {
        copyCommand()
        actions.openTerminal()
    }

    public func remindLater() { checker.remindLater() }

    public func skip() { checker.skip(update) }
}
