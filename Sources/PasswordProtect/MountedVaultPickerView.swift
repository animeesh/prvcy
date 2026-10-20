import SwiftUI

struct MountedVaultPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var isLocking = false

    let vaults: [MountedVault]
    let onLock: (MountedVault) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a Mounted Vault")
                .font(.title2)
                .fontWeight(.semibold)

            List(vaults) { vault in
                Button {
                    lock(vault)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vault.imageURL.lastPathComponent)
                            .fontWeight(.medium)
                        Text(vault.mountPoint.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLocking)
            }
            .frame(minHeight: 120, maxHeight: 260)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .disabled(isLocking)

                Spacer()

                if isLocking {
                    ProgressView()
                        .controlSize(.small)
                }

                Text("Files in use may prevent locking.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func lock(_ vault: MountedVault) {
        isLocking = true
        errorMessage = nil

        Task {
            do {
                try await onLock(vault)
            } catch {
                errorMessage = error.localizedDescription
                isLocking = false
            }
        }
    }
}
