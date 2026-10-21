import XCTest
import UpdateNotice
@testable import UpdateNoticeUI

private struct StubFetcher: UpdateFetching {
    func fetchLatest(from url: URL) async throws -> LatestRelease { LatestRelease(version: "2.0.5") }
}

@MainActor
private final class FakeActions: UpdateActions {
    var clipboard: [String] = []
    var terminalOpened = 0
    func copyToClipboard(_ text: String) { clipboard.append(text) }
    func openTerminal() { terminalOpened += 1 }
}

@MainActor
final class UpdatePromptModelTests: XCTestCase {
    private var suite = ""

    private func make() -> (UpdatePromptModel, UpdateChecker, UpdatePreferences, FakeActions) {
        suite = "updatenotice.ui.tests.\(UUID().uuidString)"
        let preferences = UpdatePreferences(defaults: UserDefaults(suiteName: suite)!)
        let configuration = UpdateConfiguration(
            appName: "Correctify", caskName: "correctify", feedURL: URL(string: "https://casks.kavaz.org/correctify/latest.json")!,
            currentVersion: "2.0.4"
        )
        let checker = UpdateChecker(configuration: configuration, preferences: preferences, fetcher: StubFetcher())
        let actions = FakeActions()
        let update = AvailableUpdate(version: "2.0.5", notes: "Fixes")
        checker.presented = update
        return (UpdatePromptModel(update: update, checker: checker, actions: actions), checker, preferences, actions)
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func testCopyPutsTheExactBrewCommandOnTheClipboard() {
        let (model, _, _, actions) = make()
        model.copyCommand()
        XCTAssertEqual(actions.clipboard, ["brew update && brew upgrade --cask correctify"])
        XCTAssertTrue(model.didCopy)
        XCTAssertEqual(actions.terminalOpened, 0)
    }

    func testCopyAndOpenTerminalCopiesTheSameCommandAndOpensTerminal() {
        let (model, _, _, actions) = make()
        model.copyAndOpenTerminal()
        XCTAssertEqual(actions.clipboard, ["brew update && brew upgrade --cask correctify"])
        XCTAssertEqual(actions.terminalOpened, 1)
    }

    func testSkipStoresTheVersionAndClosesTheWindow() {
        let (model, checker, preferences, _) = make()
        model.skip()
        XCTAssertEqual(preferences.skippedVersion, "2.0.5")
        XCTAssertNil(checker.presented)
    }

    func testRemindLaterStoresNothingAndClosesTheWindow() {
        let (model, checker, preferences, _) = make()
        model.remindLater()
        XCTAssertNil(preferences.skippedVersion)
        XCTAssertNil(checker.presented)
    }

    func testExposesTheVersionsForTheWindow() {
        let (model, _, _, _) = make()
        XCTAssertEqual(model.currentVersion, "2.0.4")
        XCTAssertEqual(model.appName, "Correctify")
        XCTAssertEqual(model.update.version, "2.0.5")
    }

    func testDefaultStringsAreEnglishAndHaveNoEmDashes() {
        let strings = UpdateStrings()
        XCTAssertEqual(strings.windowTitle("App", "1.2"), "App 1.2 is available")
        let all = [
            strings.windowTitle("App", "1.2"), strings.currentVersion("1.1"), strings.copyCommand, strings.copyAndOpenTerminal,
            strings.copied, strings.remindLater, strings.skipVersion, strings.sectionTitle, strings.automaticChecks,
            strings.automaticChecksHint("example.com"), strings.frequency, strings.everyLaunch, strings.daily, strings.weekly,
            strings.checkNow, strings.checking, strings.upToDate, strings.availableShort("1.2"), strings.couldNotCheck,
            strings.lastChecked("now"), strings.never, strings.skippedVersion("1.2"), strings.resetSkipped, strings.menuItem,
        ]
        for text in all {
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.contains("\u{2014}"), text)
        }
    }
}
