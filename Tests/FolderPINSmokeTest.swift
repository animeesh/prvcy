import Foundation

@main
struct FolderPINSmokeTest {
    static func main() throws {
        let suiteName = "PasswordProtectSmoke-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SmokeTestFailure("could not create isolated settings for the smoke test")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Folder with spaces", isDirectory: true)
        let service = FolderPINService(defaults: defaults)
        let correctPIN = Data("2468".utf8)

        try require(!service.hasPIN(for: folder), "new folder should not already have a PIN")
        try service.setPIN(correctPIN, for: folder)
        try require(service.hasPIN(for: folder), "PIN should be saved for the selected folder")
        try service.verifyPIN(correctPIN, for: folder)

        do {
            try service.verifyPIN(Data("1357".utf8), for: folder)
            throw SmokeTestFailure("an incorrect PIN was accepted")
        } catch FolderPINError.incorrectPIN {
        }

        do {
            try service.verifyPIN(correctPIN, for: folder.appendingPathComponent("different"))
            throw SmokeTestFailure("PIN for another folder was accepted")
        } catch FolderPINError.pinNotSet {
        }

        try service.setPIN(Data("8642".utf8), for: folder)
        try service.verifyPIN(Data("8642".utf8), for: folder)
        do {
            try service.verifyPIN(correctPIN, for: folder)
            throw SmokeTestFailure("the old PIN was accepted after changing it")
        } catch FolderPINError.incorrectPIN {
        }

        print("PASS: PIN match/rejection, folder-specific PIN, and PIN changes.")
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else {
            throw SmokeTestFailure(message)
        }
    }
}

private struct SmokeTestFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
