import SwiftUI

struct PasswordPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isCreating = false

    let title: String
    let confirmationRequired: Bool
    let actionTitle: String
    let onSubmit: (Data) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            if confirmationRequired {
                Text("Use a strong, unique password. It cannot be recovered if lost.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            SecureField("Password", text: $password)
                .disabled(isCreating)

            if confirmationRequired {
                SecureField("Confirm Password", text: $confirmation)
                    .disabled(isCreating)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .disabled(isCreating)

                Spacer()

                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(actionTitle) {
                    submitPassword()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    isCreating
                        || password.isEmpty
                        || (confirmationRequired && password != confirmation)
                )
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func submitPassword() {
        guard !password.contains("\n"), !password.contains("\r") else {
            errorMessage = "Passwords cannot contain line breaks."
            return
        }

        let passwordData = Data(password.utf8)
        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await onSubmit(passwordData)
                password = ""
                confirmation = ""
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}
