import AppKit
import SwiftUI

struct SettingsFooterView: View {
    @ObservedObject var viewModel: DailyBriefViewModel
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        HStack(spacing: 8) {
            if let error = viewModel.lastErrorMessage ?? launchAtLogin.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text(viewModel.storageURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Menu {
                Button("Choose Storage Folder...") {
                    chooseStorageFolder()
                }

                Button("Use Default Storage Folder") {
                    viewModel.resetToDefaultStorageFolder()
                }

                Divider()

                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))

                Divider()

                Button("Quit DailyBrief") {
                    viewModel.saveImmediately()
                    NSApp.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 24)
            }
            .menuStyle(.borderlessButton)
            .help("DailyBrief settings")
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private func chooseStorageFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose DailyBrief Storage Folder"
        panel.message = "DailyBrief will store daily JSON files in this folder."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = viewModel.storageURL

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        viewModel.useStorageFolder(url)
    }
}
