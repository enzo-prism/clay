import Foundation

#if DEBUG
enum UncaughtExceptionLogger {
    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            write(exception: exception)
        }
    }

    private static func write(exception: NSException) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let header = [
            "timestamp=\(timestamp)",
            "name=\(exception.name.rawValue)",
            "reason=\(exception.reason ?? "(nil)")"
        ].joined(separator: "\n")

        let stack = exception.callStackSymbols.joined(separator: "\n")
        let payload = "\(header)\n\ncallStackSymbols:\n\(stack)\n"

        let url = exceptionLogURL()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try payload.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // If writing fails, there's not much else we can do in an uncaught exception path.
        }
    }

    private static func exceptionLogURL() -> URL {
        // In the sandbox, this resolves to the app container's Application Support directory.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clay", isDirectory: true).appendingPathComponent("last_exception.txt")
    }
}
#endif
