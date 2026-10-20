import Foundation

struct ProcessResult: Sendable {
    let status: Int32
    let standardOutput: String
    let standardError: String
}

struct ProcessRunner {
    static func run(
        executable: URL,
        arguments: [String],
        standardInput: Data = Data()
    ) throws -> ProcessResult {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputBuffer = ProcessOutputBuffer()
        let errorBuffer = ProcessOutputBuffer()
        let outputReadCompleted = DispatchGroup()
        let errorReadCompleted = DispatchGroup()

        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputReadCompleted.enter()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                outputReadCompleted.leave()
            } else {
                outputBuffer.append(data)
            }
        }

        errorReadCompleted.enter()
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                errorReadCompleted.leave()
            } else {
                errorBuffer.append(data)
            }
        }

        do {
            try process.run()
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw DiskImageError.unsupportedSystemUtility
        }

        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: standardInput)
            try inputPipe.fileHandleForWriting.close()
        } catch {
            process.terminate()
            process.waitUntilExit()
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw DiskImageError.interruptedOrFailed
        }

        process.waitUntilExit()
        outputReadCompleted.wait()
        errorReadCompleted.wait()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        return ProcessResult(
            status: process.terminationStatus,
            standardOutput: outputBuffer.string,
            standardError: errorBuffer.string
        )
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let maximumSize = 16_384

    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }

        let remaining = maximumSize - data.count
        guard remaining > 0 else { return }
        data.append(newData.prefix(remaining))
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
