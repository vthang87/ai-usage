import Darwin
import Foundation

enum ProcessCapture {
    static func run(executable: URL, arguments: [String], timeout: TimeInterval = 12) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = BinaryLocator.processEnvironment()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CollectorError.processFailed("Could not start \(executable.lastPathComponent)")
        }

        let stdoutFD = stdout.fileHandleForReading.fileDescriptor
        let stderrFD = stderr.fileHandleForReading.fileDescriptor
        setNonBlocking(stdoutFD)
        setNonBlocking(stderrFD)

        var output = Data()
        var errorOutput = Data()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            output.append(readAvailable(stdoutFD))
            errorOutput.append(readAvailable(stderrFD))
            if !process.isRunning {
                output.append(readAvailable(stdoutFD))
                errorOutput.append(readAvailable(stderrFD))
                break
            }
            usleep(50_000)
        }

        if process.isRunning {
            process.terminate()
            usleep(200_000)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            throw CollectorError.timeout
        }

        let text = String(data: output, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let errorText = String(data: errorOutput, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CollectorError.processFailed(
                errorText?.isEmpty == false
                    ? errorText!
                    : "\(executable.lastPathComponent) exited \(process.terminationStatus)"
            )
        }
        return text
    }

    private static func setNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0 else { return }
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }

    private static func readAvailable(_ fd: Int32) -> Data {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let n = Darwin.read(fd, &buffer, buffer.count)
        if n > 0 {
            return Data(buffer[0..<n])
        }
        return Data()
    }
}
