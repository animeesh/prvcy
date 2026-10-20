import Foundation

enum DiskImageError: LocalizedError {
    case invalidSelection
    case unsupportedSystemUtility
    case existingDestination
    case destinationInsideSource
    case permissionDenied
    case insufficientSpace
    case interruptedOrFailed
    case outputMissing
    case invalidPassword
    case mountFailed
    case unsupportedDiskImage
    case volumeBusy
    case notMounted
    case createdButCouldNotVerify
    case createdButStillMounted

    var errorDescription: String? {
        switch self {
        case .invalidSelection:
            "Select a source folder and a destination for the vault."
        case .unsupportedSystemUtility:
            "This macOS installation does not support the required encrypted disk-image operation."
        case .existingDestination:
            "The destination already exists. Choose a different location."
        case .destinationInsideSource:
            "Choose a vault destination outside the selected source folder."
        case .permissionDenied:
            "macOS denied access to the selected folder or destination."
        case .insufficientSpace:
            "There is not enough free space to create the encrypted vault."
        case .interruptedOrFailed:
            "Vault creation did not complete. Check the destination before trying again."
        case .outputMissing:
            "The disk-image utility reported success, but the vault was not found at the selected destination."
        case .invalidPassword:
            "The password was not accepted, or macOS could not unlock this vault."
        case .mountFailed:
            "macOS unlocked the image but could not find a mounted volume."
        case .unsupportedDiskImage:
            "Choose an encrypted .sparsebundle vault created by Password Protect."
        case .volumeBusy:
            "The vault is in use. Close files and Finder windows in the vault, then try locking it again."
        case .notMounted:
            "This vault is no longer mounted."
        case .createdButCouldNotVerify:
            "The encrypted vault file was created, but macOS could not verify that it mounts. Check the image before relying on it."
        case .createdButStillMounted:
            "The encrypted vault was created, but its verification mount could not be ejected. The vault may still be mounted; use Lock Vault after closing any open files."
        }
    }
}

struct DiskImageService: Sendable {
    private let diskutilURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
    private let hdiutilURL = URL(fileURLWithPath: "/usr/bin/hdiutil")

    func createVault(from sourceFolder: URL, at destination: URL, password: Data) throws {
        guard FileManager.default.fileExists(atPath: diskutilURL.path) else {
            throw DiskImageError.unsupportedSystemUtility
        }

        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw DiskImageError.existingDestination
        }

        let sourcePath = sourceFolder.resolvingSymlinksInPath().standardizedFileURL.path
        let destinationPath = destination.resolvingSymlinksInPath().standardizedFileURL.path
        let sourcePrefix = sourcePath == "/" ? "/" : sourcePath + "/"
        guard !destinationPath.hasPrefix(sourcePrefix) else {
            throw DiskImageError.destinationInsideSource
        }

        var passwordInput = password
        passwordInput.append(0x0A)
        defer {
            passwordInput.resetBytes(in: passwordInput.startIndex..<passwordInput.endIndex)
        }

        let result = try ProcessRunner.run(
            executable: diskutilURL,
            arguments: [
                "image", "create", "from",
                "--encrypt",
                "--stdinpassphrase",
                "--format", "UDSB",
                sourceFolder.path,
                destination.path
            ],
            standardInput: passwordInput
        )

        guard result.status == 0 else {
            throw classifyFailure(result.standardError + result.standardOutput)
        }

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw DiskImageError.outputMissing
        }

        let verificationMount: MountedVault
        do {
            verificationMount = try attachVault(at: destination, password: password)
        } catch {
            throw DiskImageError.createdButCouldNotVerify
        }

        do {
            try lockVault(verificationMount)
        } catch {
            throw DiskImageError.createdButStillMounted
        }
    }

    func unlockVault(at imageURL: URL, password: Data) throws -> MountedVault {
        guard imageURL.pathExtension.lowercased() == "sparsebundle" else {
            throw DiskImageError.unsupportedDiskImage
        }
        return try attachVault(at: imageURL, password: password)
    }

    func mountedVaults() throws -> [MountedVault] {
        let result = try ProcessRunner.run(
            executable: hdiutilURL,
            arguments: ["info", "-plist"]
        )
        guard result.status == 0 else {
            throw classifyFailure(result.standardError + result.standardOutput)
        }

        guard
            let data = result.standardOutput.data(using: .utf8),
            let propertyList = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ),
            let root = propertyList as? [String: Any],
            let images = root["images"] as? [[String: Any]]
        else {
            throw DiskImageError.interruptedOrFailed
        }

        return images.compactMap { image in
            guard
                let path = image["image-path"] as? String,
                URL(fileURLWithPath: path).pathExtension.lowercased() == "sparsebundle",
                let entities = image["system-entities"] as? [[String: Any]],
                let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first,
                let device = diskDevice(in: entities)
            else {
                return nil
            }
            return MountedVault(
                imageURL: URL(fileURLWithPath: path),
                mountPoint: URL(fileURLWithPath: mountPoint),
                device: device
            )
        }
        .sorted { $0.imageURL.lastPathComponent < $1.imageURL.lastPathComponent }
    }

    func lockVault(_ vault: MountedVault) throws {
        let result = try ProcessRunner.run(
            executable: diskutilURL,
            arguments: ["eject", vault.device]
        )

        guard result.status == 0 else {
            let diagnostic = result.standardError + result.standardOutput
            let message = diagnostic.lowercased()
            if message.contains("busy") || message.contains("in use") {
                throw DiskImageError.volumeBusy
            }
            if message.contains("not found") || message.contains("not currently mounted") {
                throw DiskImageError.notMounted
            }
            throw classifyFailure(diagnostic)
        }
    }

    private func attachVault(at imageURL: URL, password: Data) throws -> MountedVault {
        var passwordInput = password
        passwordInput.append(0x0A)
        defer {
            passwordInput.resetBytes(in: passwordInput.startIndex..<passwordInput.endIndex)
        }

        let result = try ProcessRunner.run(
            executable: diskutilURL,
            arguments: [
                "image", "attach",
                "--stdinpassphrase",
                imageURL.path
            ],
            standardInput: passwordInput
        )

        guard result.status == 0 else {
            throw classifyMountFailure(result.standardError + result.standardOutput)
        }

        let standardizedImagePath = imageURL.standardizedFileURL.path
        guard let mountedVault = try mountedVaults().first(where: {
            $0.imageURL.standardizedFileURL.path == standardizedImagePath
        }) else {
            throw DiskImageError.mountFailed
        }
        return mountedVault
    }

    private func classifyFailure(_ diagnostic: String) -> DiskImageError {
        let message = diagnostic.lowercased()
        if message.contains("permission denied") || message.contains("operation not permitted") {
            return .permissionDenied
        }
        if message.contains("no space left") || message.contains("not enough space") {
            return .insufficientSpace
        }
        if message.contains("already exists") || message.contains("file exists") {
            return .existingDestination
        }
        if message.contains("unrecognized") || message.contains("unsupported") {
            return .unsupportedSystemUtility
        }
        return .interruptedOrFailed
    }

    private func classifyMountFailure(_ diagnostic: String) -> DiskImageError {
        let message = diagnostic.lowercased()
        if message.contains("authentication") || message.contains("passphrase") {
            return .invalidPassword
        }
        return classifyFailure(diagnostic)
    }

    private func diskDevice(in entities: [[String: Any]]) -> String? {
        let devices = entities.compactMap { $0["dev-entry"] as? String }
        if let wholeDisk = devices.first(where: { $0.range(of: #"^/dev/disk\d+$"#, options: .regularExpression) != nil }) {
            return wholeDisk
        }
        return devices.first
    }

}

struct MountedVault: Identifiable, Sendable {
    let imageURL: URL
    let mountPoint: URL
    let device: String

    var id: String { mountPoint.path }
}
