import CryptoKit
import Foundation
import Security

enum FolderPINError: LocalizedError, Equatable {
    case pinNotSet
    case incorrectPIN
    case couldNotSavePIN

    var errorDescription: String? {
        switch self {
        case .pinNotSet:
            "No PIN is set for this folder. Choose Set or Change PIN first."
        case .incorrectPIN:
            "That PIN is incorrect."
        case .couldNotSavePIN:
            "The PIN could not be saved. Please try again."
        }
    }
}

struct FolderPINService {
    private struct PINRecord: Codable {
        let salt: Data
        let digest: Data
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func setPIN(_ pin: Data, for folder: URL) throws {
        var salt = Data(count: 16)
        guard salt.withUnsafeMutableBytes({
            SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
        }) == errSecSuccess else {
            throw FolderPINError.couldNotSavePIN
        }

        let record = PINRecord(salt: salt, digest: digest(pin, salt: salt))
        salt.resetBytes(in: salt.startIndex..<salt.endIndex)

        do {
            let data = try JSONEncoder().encode(record)
            defaults.set(data, forKey: storageKey(for: folder))
        } catch {
            throw FolderPINError.couldNotSavePIN
        }
    }

    func hasPIN(for folder: URL) -> Bool {
        defaults.data(forKey: storageKey(for: folder)) != nil
    }

    func verifyPIN(_ pin: Data, for folder: URL) throws {
        guard let data = defaults.data(forKey: storageKey(for: folder)),
              let record = try? JSONDecoder().decode(PINRecord.self, from: data) else {
            throw FolderPINError.pinNotSet
        }

        guard digest(pin, salt: record.salt) == record.digest else {
            throw FolderPINError.incorrectPIN
        }
    }

    private func storageKey(for folder: URL) -> String {
        let path = folder.resolvingSymlinksInPath().standardizedFileURL.path
        let pathDigest = SHA256.hash(data: Data(path.utf8))
        let identifier = pathDigest.map { String(format: "%02x", $0) }.joined()
        return "folder-pin.\(identifier)"
    }

    private func digest(_ pin: Data, salt: Data) -> Data {
        var input = salt
        input.append(pin)
        return Data(SHA256.hash(data: input))
    }
}
