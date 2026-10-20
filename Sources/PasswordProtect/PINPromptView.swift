import SwiftUI

struct PINPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    let title: String
    let isCreating: Bool
    let onSubmit: (Data) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter the same PIN in both fields. This convenience prompt does not encrypt or protect the folder.")
                .font(.callout)
                .foregroundStyle(.orange)

            SecureField(isCreating ? "Create PIN" : "PIN", text: $pin)
                .disabled(isWorking)

            if isCreating {
                SecureField("Confirm PIN", text: $confirmation)
                    .disabled(isWorking)
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
                .disabled(isWorking)

                Spacer()

                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(isCreating ? "Save PIN & Open Folder" : "Open Folder") {
                    submitPIN()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    isWorking
                        || !isValidPIN(pin)
                        || (isCreating && pin != confirmation)
                )
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func submitPIN() {
        let pinData = Data(pin.utf8)
        isWorking = true
        errorMessage = nil

        Task {
            do {
                try await onSubmit(pinData)
                pin = ""
                confirmation = ""
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func isValidPIN(_ pin: String) -> Bool {
        !pin.isEmpty && pin.allSatisfy(\.isNumber)
    }
}
