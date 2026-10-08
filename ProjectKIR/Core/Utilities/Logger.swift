import Foundation

/// Basit loglama — spec 217.
/// Ring buffer debug overlay için tutulur, console'a da yazar.
enum KIRLog {

    private static var buffer: [String] = []
    private static let lock = NSLock()
    private static let maxLines = 120

    static func info(_ message: String) { log("INFO", message) }
    static func warn(_ message: String) { log("WARN", message) }
    static func error(_ message: String) { log("ERR ", message) }

    private static func log(_ level: String, _ message: String) {
        let line = "[\(level)] \(message)"
        print("KIR \(line)")
        lock.lock()
        buffer.append(line)
        if buffer.count > maxLines { buffer.removeFirst(buffer.count - maxLines) }
        lock.unlock()
    }

    static func recentLines(_ count: Int) -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(buffer.suffix(count))
    }
}
