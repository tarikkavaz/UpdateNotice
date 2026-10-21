import XCTest
@testable import UpdateNotice

private final class FakeFetcher: UpdateFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _result: Result<LatestRelease, Error>
    private var _calls = 0

    init(_ result: Result<LatestRelease, Error>) { _result = result }

    var calls: Int { lock.withLock { _calls } }
    func set(_ result: Result<LatestRelease, Error>) { lock.withLock { _result = result } }

    func fetchLatest(from url: URL) async throws -> LatestRelease {
        try lock.withLock { _calls += 1; return try _result.get() }
    }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

@MainActor
final class UpdateCheckerTests: XCTestCase {
    private let hour: TimeInterval = 3600
    private var suites: [String] = []

    private func defaults() -> UserDefaults {
        let name = "updatenotice.tests.\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() async throws {
        for name in suites { UserDefaults().removePersistentDomain(forName: name) }
    }

    private func make(
        current: String = "2.0.4",
        fetcher: FakeFetcher,
        defaults: UserDefaults? = nil,
        clock: Clock = Clock()
    ) -> (UpdateChecker, UpdatePreferences) {
        let preferences = UpdatePreferences(defaults: defaults ?? self.defaults())
        let configuration = UpdateConfiguration(
            appName: "App", caskName: "app", feedURL: URL(string: "https://example.com/latest.json")!, currentVersion: current
        )
        let checker = UpdateChecker(configuration: configuration, preferences: preferences, fetcher: fetcher, now: { clock.now })
        return (checker, preferences)
    }

    private func release(_ version: String, notes: String? = "Fixes") -> Result<LatestRelease, Error> {
        .success(LatestRelease(version: version, notes: notes))
    }

    // MARK: Automatic checks

    func testNewerVersionIsPresentedOnLaunch() async {
        let (checker, _) = make(fetcher: FakeFetcher(release("2.0.5")))
        await checker.checkOnLaunch()
        XCTAssertEqual(checker.presented, AvailableUpdate(version: "2.0.5", notes: "Fixes"))
        XCTAssertEqual(checker.available?.version, "2.0.5")
    }

    func testSameOrOlderVersionShowsNothing() async {
        for remote in ["2.0.4", "2.0.3", "1.9.0"] {
            let (checker, _) = make(fetcher: FakeFetcher(release(remote)))
            await checker.checkOnLaunch()
            XCTAssertNil(checker.presented, remote)
            XCTAssertNil(checker.available, remote)
        }
    }

    func testTenIsNewerThanNine() async {
        let (checker, _) = make(current: "2.0.9", fetcher: FakeFetcher(release("2.0.10")))
        await checker.checkOnLaunch()
        XCTAssertEqual(checker.presented?.version, "2.0.10")
    }

    func testToggleOffMakesNoRequest() async {
        let fetcher = FakeFetcher(release("2.0.5"))
        let (checker, preferences) = make(fetcher: fetcher)
        preferences.automaticChecks = false
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 0)
        XCTAssertNil(checker.presented)
    }

    func testSuccessfulCheckRecordsTheTime() async {
        let clock = Clock()
        let (checker, preferences) = make(fetcher: FakeFetcher(release("2.0.5")), clock: clock)
        XCTAssertNil(preferences.lastChecked)
        await checker.checkOnLaunch()
        XCTAssertEqual(preferences.lastChecked, clock.now)
    }

    // MARK: Throttle

    func testDailyThrottle() async {
        let clock = Clock()
        let fetcher = FakeFetcher(release("2.0.5"))
        let (checker, preferences) = make(fetcher: fetcher, clock: clock)
        preferences.frequency = .daily
        await checker.checkOnLaunch()
        clock.advance(23 * hour)
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 1)
        clock.advance(2 * hour)
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 2)
    }

    func testWeeklyThrottle() async {
        let clock = Clock()
        let fetcher = FakeFetcher(release("2.0.5"))
        let (checker, preferences) = make(fetcher: fetcher, clock: clock)
        preferences.frequency = .weekly
        await checker.checkOnLaunch()
        clock.advance(6 * 24 * hour)
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 1)
        clock.advance(2 * 24 * hour)
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 2)
    }

    func testEveryLaunchHasNoThrottle() async {
        let fetcher = FakeFetcher(release("2.0.5"))
        let (checker, preferences) = make(fetcher: fetcher)
        preferences.frequency = .everyLaunch
        await checker.checkOnLaunch()
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 2)
    }

    // MARK: Failures

    func testAutomaticFailuresAreSilentAndDoNotTouchLastChecked() async {
        let failures: [Error] = [UpdateError.badStatus(404), UpdateError.invalidResponse, URLError(.timedOut)]
        for failure in failures {
            let (checker, preferences) = make(fetcher: FakeFetcher(.failure(failure)))
            await checker.checkOnLaunch()
            XCTAssertNil(checker.presented)
            XCTAssertNil(checker.available)
            XCTAssertNil(preferences.lastChecked)
        }
    }

    func testMalformedRemoteVersionIsAFailure() async {
        let (checker, preferences) = make(fetcher: FakeFetcher(release("soon")))
        await checker.checkOnLaunch()
        XCTAssertNil(checker.presented)
        XCTAssertNil(preferences.lastChecked)
        let result = await checker.checkNow()
        XCTAssertEqual(result, .failed)
    }

    // MARK: Skip and remind

    func testSkippedVersionStaysHiddenAndANewerOneShowsAgain() async {
        let clock = Clock()
        let fetcher = FakeFetcher(release("2.0.5"))
        let (checker, preferences) = make(fetcher: fetcher, clock: clock)
        await checker.checkOnLaunch()
        let update = try! XCTUnwrap(checker.presented)
        checker.skip(update)
        XCTAssertNil(checker.presented)
        XCTAssertNil(checker.available)
        XCTAssertEqual(preferences.skippedVersion, "2.0.5")

        clock.advance(25 * hour)
        await checker.checkOnLaunch()
        XCTAssertNil(checker.presented, "same version, skipped")

        fetcher.set(release("2.0.6"))
        clock.advance(25 * hour)
        await checker.checkOnLaunch()
        XCTAssertEqual(checker.presented?.version, "2.0.6")
    }

    func testResetBringsTheSkippedVersionBack() async {
        let (checker, preferences) = make(fetcher: FakeFetcher(release("2.0.5")))
        await checker.checkOnLaunch()
        checker.skip(try! XCTUnwrap(checker.presented))
        checker.resetSkipped()
        XCTAssertNil(preferences.skippedVersion)
        XCTAssertEqual(checker.available?.version, "2.0.5")
    }

    func testRemindLaterClosesTheWindowAndKeepsTheUpdateKnown() async {
        let clock = Clock()
        let fetcher = FakeFetcher(release("2.0.5"))
        let (checker, preferences) = make(fetcher: fetcher, clock: clock)
        await checker.checkOnLaunch()
        checker.remindLater()
        XCTAssertNil(checker.presented)
        XCTAssertEqual(checker.available?.version, "2.0.5")
        XCTAssertNil(preferences.skippedVersion)

        await checker.checkOnLaunch()
        XCTAssertNil(checker.presented, "inside the interval")
        XCTAssertEqual(fetcher.calls, 1)

        clock.advance(25 * hour)
        await checker.checkOnLaunch()
        XCTAssertEqual(checker.presented?.version, "2.0.5", "after the interval")
    }

    func testMenuEntryShowsTheWindowAgain() async {
        let (checker, _) = make(fetcher: FakeFetcher(release("2.0.5")))
        await checker.checkOnLaunch()
        checker.remindLater()
        checker.showAvailable()
        XCTAssertEqual(checker.presented?.version, "2.0.5")
    }

    func testShowAvailableDoesNothingWithoutAnUpdate() {
        let (checker, _) = make(fetcher: FakeFetcher(release("2.0.4")))
        checker.showAvailable()
        XCTAssertNil(checker.presented)
    }

    // MARK: Check now

    func testCheckNowIgnoresTheThrottleAndTheToggle() async {
        let fetcher = FakeFetcher(release("2.0.4"))
        let (checker, preferences) = make(fetcher: fetcher)
        preferences.automaticChecks = false
        await checker.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 0)
        let first = await checker.checkNow()
        let second = await checker.checkNow()
        XCTAssertEqual(first, .upToDate)
        XCTAssertEqual(second, .upToDate)
        XCTAssertEqual(fetcher.calls, 2)
    }

    func testCheckNowReportsAnAvailableUpdateAndPresentsIt() async {
        let (checker, _) = make(fetcher: FakeFetcher(release("2.0.5")))
        let result = await checker.checkNow()
        XCTAssertEqual(result, .available(AvailableUpdate(version: "2.0.5", notes: "Fixes")))
        XCTAssertEqual(checker.presented?.version, "2.0.5")
    }

    func testCheckNowShowsASkippedVersionAnyway() async {
        let (checker, preferences) = make(fetcher: FakeFetcher(release("2.0.5")))
        preferences.skippedVersion = "2.0.5"
        let result = await checker.checkNow()
        XCTAssertEqual(result, .available(AvailableUpdate(version: "2.0.5", notes: "Fixes")))
        XCTAssertNil(checker.available, "the menu entry still honors the skip")
    }

    func testCheckNowUpdatesLastCheckedOnSuccessOnly() async {
        let clock = Clock()
        let fetcher = FakeFetcher(release("2.0.4"))
        let (checker, preferences) = make(fetcher: fetcher, clock: clock)
        await checker.checkNow()
        let first = preferences.lastChecked
        XCTAssertEqual(first, clock.now)

        clock.advance(hour)
        fetcher.set(.failure(URLError(.notConnectedToInternet)))
        let result = await checker.checkNow()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(preferences.lastChecked, first)
    }

    // MARK: Persistence

    func testSettingsPersistAcrossARelaunch() async {
        let shared = defaults()
        let (checker, preferences) = make(fetcher: FakeFetcher(release("2.0.5")), defaults: shared)
        preferences.automaticChecks = false
        preferences.frequency = .weekly
        await checker.checkNow()
        preferences.skippedVersion = "2.0.3"

        let reloaded = UpdatePreferences(defaults: shared)
        XCTAssertFalse(reloaded.automaticChecks)
        XCTAssertEqual(reloaded.frequency, .weekly)
        XCTAssertEqual(reloaded.skippedVersion, "2.0.3")
        XCTAssertNotNil(reloaded.lastChecked)
        XCTAssertEqual(reloaded.latestVersion, "2.0.5")
    }

    func testDefaults() {
        let preferences = UpdatePreferences(defaults: defaults())
        XCTAssertTrue(preferences.automaticChecks)
        XCTAssertEqual(preferences.frequency, .daily)
        XCTAssertNil(preferences.lastChecked)
        XCTAssertNil(preferences.skippedVersion)
    }

    func testKnownUpdateSurvivesARelaunchInsideTheInterval() async {
        let shared = defaults()
        let (first, _) = make(fetcher: FakeFetcher(release("2.0.5")), defaults: shared)
        await first.checkOnLaunch()

        let fetcher = FakeFetcher(release("2.0.5"))
        let (second, _) = make(fetcher: fetcher, defaults: shared)
        XCTAssertEqual(second.available?.version, "2.0.5")
        XCTAssertEqual(second.available?.notes, "Fixes")
        await second.checkOnLaunch()
        XCTAssertEqual(fetcher.calls, 0)
    }

    func testAnAppThatWasUpdatedForgetsTheOldNotice() {
        let shared = defaults()
        let stored = UpdatePreferences(defaults: shared)
        stored.latestVersion = "2.0.5"
        let (checker, _) = make(current: "2.0.5", fetcher: FakeFetcher(release("2.0.5")), defaults: shared)
        XCTAssertNil(checker.available)
    }

    func testBrewCommand() {
        let configuration = UpdateConfiguration(
            appName: "Correctify", caskName: "correctify", feedURL: URL(string: "https://example.com")!, currentVersion: "1"
        )
        XCTAssertEqual(configuration.brewCommand, "brew update && brew upgrade --cask correctify")
    }
}
