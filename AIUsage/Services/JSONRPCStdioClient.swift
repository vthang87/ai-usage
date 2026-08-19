import Darwin
import Foundation

enum JSONRPCStdioClient {
    static func call(
        executable: URL,
        arguments: [String],
        request: [String: Any],
        timeout: TimeInterval = 20
    ) throws -> Any {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = BinaryLocator.processEnvironment()

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw CollectorError.processFailed("Could not start \(executable.lastPathComponent)")
        }

        let stdoutFD = stdout.fileHandleForReading.fileDescriptor
        let stderrFD = stderr.fileHandleForReading.fileDescriptor
        setNonBlocking(stdoutFD)
        setNonBlocking(stderrFD)
        drain(stderrFD)

        defer { terminate(process) }

        let deadline = Date().addingTimeInterval(timeout)
        try send([
            "method": "initialize",
            "id": 0,
            "params": [
                "clientInfo": [
                    "name": "ai_usage",
                    "title": "AI Usage",
                    "version": "0.0.2",
                ],
            ],
        ], to: stdin)
        _ = try readMessage(from: stdoutFD, process: process, matchingID: 0, deadline: deadline)
        try send(["method": "initialized", "params": [:] as [String: Any]], to: stdin)
        try send(request, to: stdin)
        let result = try readMessage(from: stdoutFD, process: process, matchingID: request["id"], deadline: deadline)
        try? stdin.fileHandleForWriting.close()
        return result
    }

    private static func send(_ object: [String: Any], to pipe: Pipe) throws {
        let data = try JSONSerialization.data(withJSONObject: object) + Data([0x0A])
        try data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            var sent = 0
            while sent < data.count {
                let n = Darwin.write(pipe.fileHandleForWriting.fileDescriptor, base + sent, data.count - sent)
                if n <= 0 { throw CollectorError.rpc("Could not write to CLI") }
                sent += n
            }
        }
    }

    private static func setNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0 else { return }
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }

    private static func drain(_ fd: Int32) {
        DispatchQueue.global(qos: .utility).async {
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = Darwin.read(fd, &buffer, buffer.count)
                if n > 0 { continue }
                if n == 0 { break }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    usleep(50_000)
                    continue
                }
                break
            }
        }
    }

    private static func readAvailable(_ fd: Int32) -> Data {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let n = Darwin.read(fd, &buffer, buffer.count)
        if n > 0 {
            return Data(buffer[0..<n])
        }
        return Data()
    }

    private static func readMessage(
        from fd: Int32,
        process: Process,
        matchingID expectedID: Any?,
        deadline: Date
    ) throws -> Any {
        var buffer = Data()
        while Date() < deadline {
            let chunk = readAvailable(fd)
            if chunk.isEmpty {
                if !process.isRunning, buffer.isEmpty {
                    throw CollectorError.rpc("CLI closed before returning a result")
                }
                usleep(50_000)
                continue
            }
            buffer.append(chunk)

            while let line = popLine(from: &buffer) {
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                    continue
                }
                if let expectedID, !idsEqual(object["id"], expectedID) {
                    continue
                }
                if let error = object["error"] {
                    throw CollectorError.rpc(errorDescription(error))
                }
                if let result = object["result"] {
                    return result
                }
            }
        }
        throw CollectorError.timeout
    }

    private static func popLine(from buffer: inout Data) -> Data? {
        guard let range = buffer.firstRange(of: Data([0x0A])) else { return nil }
        let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
        buffer.removeSubrange(buffer.startIndex...range.lowerBound)
        return line
    }

    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(0.5)
        while process.isRunning, Date() < deadline {
            usleep(20_000)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }

    private static func idsEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case let (left as Int, right as Int):
            left == right
        case let (left as NSNumber, right as NSNumber):
            left == right
        case let (left as String, right as String):
            left == right
        case let (left as NSNumber, right as Int):
            left.intValue == right
        case let (left as Int, right as NSNumber):
            left == right.intValue
        default:
            false
        }
    }

    private static func errorDescription(_ error: Any) -> String {
        if let object = error as? [String: Any], let message = object["message"] as? String {
            return message
        }
        return "Codex RPC error"
    }
}
