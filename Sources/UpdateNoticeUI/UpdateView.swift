import AppKit
import SwiftUI
import UpdateNotice

/// The content of the update window.
struct UpdateView: View {
    @ObservedObject var model: UpdatePromptModel
    let strings: UpdateStrings

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(strings.windowTitle(model.appName, model.update.version))
                    .font(.headline)
                Text(strings.currentVersion(model.currentVersion))
                    .foregroundStyle(.secondary)
                if let notes = model.update.notes, !notes.isEmpty {
                    Text(notes)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.didCopy {
                    Label(strings.copied, systemImage: "checkmark.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                buttons
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var buttons: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(strings.copyCommand, action: model.copyCommand)
                    .keyboardShortcut(.defaultAction)
                Button(strings.copyAndOpenTerminal, action: model.copyAndOpenTerminal)
            }
            HStack {
                Button(strings.remindLater, action: model.remindLater)
                Button(strings.skipVersion, action: model.skip)
            }
            .buttonStyle(.borderless)
        }
    }
}
