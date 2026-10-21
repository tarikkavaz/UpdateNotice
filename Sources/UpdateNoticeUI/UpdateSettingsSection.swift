import SwiftUI
import UpdateNotice

/// The "Updates" section for an app's Settings form: automatic checks, frequency, Check now,
/// the time of the last check, and the skipped version.
public struct UpdateSettingsSection: View {
    @ObservedObject private var checker: UpdateChecker
    @ObservedObject private var preferences: UpdatePreferences
    private let strings: UpdateStrings

    @State private var isChecking = false
    @State private var result: ManualCheckResult?

    public init(checker: UpdateChecker, strings: UpdateStrings = UpdateStrings()) {
        self.checker = checker
        self.preferences = checker.preferences
        self.strings = strings
    }

    public var body: some View {
        Section(strings.sectionTitle) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(strings.automaticChecks, isOn: $preferences.automaticChecks)
                Text(strings.automaticChecksHint(checker.configuration.feedURL.host() ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker(strings.frequency, selection: $preferences.frequency) {
                Text(strings.everyLaunch).tag(UpdateFrequency.everyLaunch)
                Text(strings.daily).tag(UpdateFrequency.daily)
                Text(strings.weekly).tag(UpdateFrequency.weekly)
            }
            .disabled(!preferences.automaticChecks)
            HStack {
                Button(strings.checkNow) { runCheck() }
                    .disabled(isChecking)
                Text(status)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text(strings.lastChecked(lastCheckedText))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let skipped = preferences.skippedVersion {
                HStack {
                    Text(strings.skippedVersion(skipped))
                    Button(strings.resetSkipped, action: checker.resetSkipped)
                        .buttonStyle(.borderless)
                    Spacer(minLength: 0)
                }
                .font(.callout)
            }
        }
    }

    private var lastCheckedText: String {
        guard let date = preferences.lastChecked else { return strings.never }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var status: String {
        if isChecking { return strings.checking }
        switch result {
        case nil: return ""
        case .upToDate: return strings.upToDate
        case .available(let update): return strings.availableShort(update.version)
        case .failed: return strings.couldNotCheck
        }
    }

    private func runCheck() {
        isChecking = true
        result = nil
        Task {
            result = await checker.checkNow()
            isChecking = false
        }
    }
}
