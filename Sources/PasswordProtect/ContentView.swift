import AppKit
import SwiftUI

struct ContentView: View {
    private enum ActiveSheet: String, Identifiable {
        case setPIN
        case openFolder

        var id: String { rawValue }
    }

    @State private var selectedFolder: URL?
    @State private var activeSheet: ActiveSheet?
    @State private var isAlertPresented = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isChangingPIN = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Password Protect", systemImage: "folder.badge.questionmark")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Choose a folder, enter its PIN, and open it in Finder.")
                .foregroundStyle(.secondary)

            Label {
                Text("Convenience only: this PIN does not secure the folder. Finder and other apps can still open it directly.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.callout)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button("Set or Change Folder PIN", systemImage: "key") {
                    selectFolderForSettingPIN()
                }

                Button("Enter PIN and Open Folder", systemImage: "lock.open") {
                    selectFolderToOpen()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button("Help / About", systemImage: "info.circle") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            .buttonStyle(.link)
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 440)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .setPIN:
                PINPromptView(
                    title: isChangingPIN ? "Change Folder PIN" : "Set Folder PIN",
                    isCreating: true
                ) { pin in
                    try await setPIN(pin)
                }
            case .openFolder:
                PINPromptView(title: "Enter PIN to Open Folder", isCreating: false) { pin in
                    try await openFolder(pin: pin)
                }
            }
        }
        .alert(alertTitle, isPresented: $isAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func selectFolderForSettingPIN() {
        guard let folder = selectFolder(prompt: "Choose Folder") else { return }
        selectedFolder = folder
        isChangingPIN = FolderPINService().hasPIN(for: folder)
        activeSheet = .setPIN
    }

    private func selectFolderToOpen() {
        guard let folder = selectFolder(prompt: "Choose Folder to Open") else { return }
        selectedFolder = folder

        guard FolderPINService().hasPIN(for: folder) else {
            presentAlert(
                title: "No PIN Set",
                message: "Set a PIN for this folder first. Note that Finder can still open it without this app."
            )
            return
        }

        activeSheet = .openFolder
    }

    private func selectFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func setPIN(_ pin: Data) async throws {
        guard let selectedFolder else {
            throw FolderPINError.couldNotSavePIN
        }

        try FolderPINService().setPIN(pin, for: selectedFolder)
        activeSheet = nil
        openFolderInFinder(selectedFolder)
    }

    private func openFolder(pin: Data) async throws {
        guard let selectedFolder else {
            throw FolderPINError.pinNotSet
        }

        try FolderPINService().verifyPIN(pin, for: selectedFolder)
        activeSheet = nil
        openFolderInFinder(selectedFolder)
    }

    private func openFolderInFinder(_ folderURL: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSWorkspace.shared.open(folderURL)
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isAlertPresented = true
    }
}
