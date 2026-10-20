import SwiftUI
import AppKit

struct ContentView: View {
    private enum ActiveSheet: String, Identifiable {
        case create
        case unlock
        case lock

        var id: String { rawValue }
    }

    @State private var sourceFolder: URL?
    @State private var vaultURL: URL?
    @State private var selectedVaultURL: URL?
    @State private var mountedVaults: [MountedVault] = []
    @State private var activeSheet: ActiveSheet?
    @State private var isAlertPresented = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Password Protect", systemImage: "lock.shield")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Create and manage encrypted sparsebundle vaults stored locally on this Mac.")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button("Protect a Folder", systemImage: "folder.badge.lock") {
                    selectFolderAndVaultLocation()
                }

                Button("Unlock a Vault", systemImage: "lock.open") {
                    selectVaultToUnlock()
                }

                Button("Lock Vault", systemImage: "lock") {
                    findMountedVaults()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Text("Files remain accessible while a vault is mounted. Locking unmounts it.")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Button("Help / About", systemImage: "info.circle") {
                presentAlert(
                    title: "About Password Protect",
                    message: "Vaults use AES-256 encrypted macOS disk images. Files are accessible while mounted. The original folder is never removed."
                )
            }
            .buttonStyle(.link)
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 420)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                PasswordPromptView(
                    title: "Set a Vault Password",
                    confirmationRequired: true,
                    actionTitle: "Create Encrypted Vault",
                    onSubmit: createVault
                )
            case .unlock:
                PasswordPromptView(
                    title: "Unlock Vault",
                    confirmationRequired: false,
                    actionTitle: "Unlock",
                    onSubmit: unlockVault
                )
            case .lock:
                MountedVaultPickerView(vaults: mountedVaults, onLock: lockVault)
            }
        }
        .alert(alertTitle, isPresented: $isAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func selectFolderAndVaultLocation() {
        let folderPanel = NSOpenPanel()
        folderPanel.canChooseFiles = false
        folderPanel.canChooseDirectories = true
        folderPanel.allowsMultipleSelection = false
        folderPanel.prompt = "Choose Folder"

        guard folderPanel.runModal() == .OK, let folder = folderPanel.url else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(folder.lastPathComponent).sparsebundle"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.prompt = "Choose Vault Location"

        guard savePanel.runModal() == .OK, let destination = savePanel.url else {
            return
        }

        let vaultDestination = destination.pathExtension.lowercased() == "sparsebundle"
            ? destination
            : destination.appendingPathExtension("sparsebundle")

        guard !FileManager.default.fileExists(atPath: vaultDestination.path) else {
            presentAlert(
                title: "Vault Already Exists",
                message: "Choose a different destination. Existing vaults are never overwritten."
            )
            return
        }

        sourceFolder = folder
        vaultURL = vaultDestination
        activeSheet = .create
    }

    private func createVault(password: Data) async throws {
        guard let sourceFolder, let vaultURL else {
            throw DiskImageError.invalidSelection
        }

        try await Task.detached(priority: .userInitiated) {
            try DiskImageService().createVault(
                from: sourceFolder,
                at: vaultURL,
                password: password
            )
        }.value

        activeSheet = nil
        presentAlert(
            title: "Vault Created",
            message: "The encrypted vault was created at \(vaultURL.path). The original folder was not changed."
        )
    }

    private func selectVaultToUnlock() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Unlock Vault"

        guard panel.runModal() == .OK, let imageURL = panel.url else {
            return
        }

        selectedVaultURL = imageURL
        activeSheet = .unlock
    }

    private func unlockVault(password: Data) async throws {
        guard let selectedVaultURL else {
            throw DiskImageError.invalidSelection
        }

        let mountedVault = try await Task.detached(priority: .userInitiated) {
            try DiskImageService().unlockVault(at: selectedVaultURL, password: password)
        }.value

        activeSheet = nil
        NSWorkspace.shared.activateFileViewerSelecting([mountedVault.mountPoint])
        presentAlert(
            title: "Vault Unlocked",
            message: "The vault is mounted at \(mountedVault.mountPoint.path). Its files remain accessible until it is locked."
        )
    }

    private func findMountedVaults() {
        Task {
            do {
                let vaults = try await Task.detached(priority: .userInitiated) {
                    try DiskImageService().mountedVaults()
                }.value

                guard !vaults.isEmpty else {
                    presentAlert(
                        title: "No Mounted Vaults",
                        message: "There are no mounted vaults to lock. The vault may already be locked; unlock one first."
                    )
                    return
                }

                mountedVaults = vaults
                activeSheet = .lock
            } catch {
                presentAlert(title: "Unable to Find Vaults", message: error.localizedDescription)
            }
        }
    }

    private func lockVault(_ vault: MountedVault) async throws {
        try await Task.detached(priority: .userInitiated) {
            try DiskImageService().lockVault(vault)
        }.value

        activeSheet = nil
        presentAlert(
            title: "Vault Locked",
            message: "macOS successfully unmounted the vault."
        )
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isAlertPresented = true
    }
}
