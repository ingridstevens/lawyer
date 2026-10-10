import Foundation

/// The one gate every network request in the app goes through (spec §11).
///
/// Allowed: this Mac (the local model server) and the official law site (only when the user
/// updates the laws). Everything else is refused before a connection is opened. Each allowed
/// request is logged by host and purpose, never by content, so the app can show the user
/// exactly where it connected.
public enum NetworkPolicy {
    public static let lawHost = "www.gesetze-im-internet.de"
    static let localHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    public struct Entry: Sendable, Hashable, Identifiable {
        public let id = UUID()
        public let date: Date
        public let host: String
        public let purpose: String
        public let allowed: Bool
    }

    public static func isAllowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), url.scheme == "http" || url.scheme == "https" else { return false }
        return localHosts.contains(host) || (host == lawHost && url.scheme == "https")
    }

    /// Call before every request. Throws for anything that isn't this Mac or the law site.
    public static func check(_ url: URL, purpose: String) throws {
        let allowed = isAllowed(url)
        record(Entry(date: Date(), host: url.host ?? url.absoluteString, purpose: purpose, allowed: allowed))
        guard allowed else { throw NetworkPolicyError.blocked(url.host ?? url.absoluteString) }
    }

    // MARK: Log

    private static let lock = NSLock()
    nonisolated(unsafe) private static var entries: [Entry] = []
    /// Called on every new entry, e.g. to refresh a view. Set once at app start.
    nonisolated(unsafe) public static var onRecord: (@Sendable (Entry) -> Void)?

    /// This session's connections, newest first.
    public static var log: [Entry] {
        lock.lock(); defer { lock.unlock() }
        return entries.reversed()
    }

    static func record(_ entry: Entry) {
        lock.lock()
        entries.append(entry)
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        lock.unlock()
        onRecord?(entry)
    }
}

public enum NetworkPolicyError: Error, LocalizedError {
    case blocked(String)

    public var errorDescription: String? {
        switch self {
        case .blocked(let host): "Blocked a connection to \(host). This app only connects to this Mac and, when you update the laws, to gesetze-im-internet.de."
        }
    }
}
