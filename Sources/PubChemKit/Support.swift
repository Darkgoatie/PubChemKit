import Foundation

/// Spaces requests so a client stays under PubChem's limit of 5 per second and 400 per minute.
actor RateLimiter {
    private let interval: TimeInterval
    private var nextSlot = Date.distantPast

    init(requestsPerSecond: Double) {
        self.interval = requestsPerSecond > 0 ? 1 / requestsPerSecond : 0
    }

    func wait() async {
        let now = Date()
        let start = max(now, nextSlot)
        nextSlot = start.addingTimeInterval(interval)
        let delay = start.timeIntervalSince(now)
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
    }
}

/// A small in-memory cache with an expiry and a size cap.
actor ResponseCache {
    private struct Entry { let data: Data; let expires: Date }
    private var entries: [URL: Entry] = [:]
    private let ttl: TimeInterval
    private let capacity: Int

    init(ttl: TimeInterval, capacity: Int) {
        self.ttl = ttl
        self.capacity = capacity
    }

    func get(_ url: URL) -> Data? {
        guard let e = entries[url] else { return nil }
        if e.expires < Date() { entries[url] = nil; return nil }
        return e.data
    }

    func set(_ url: URL, _ data: Data) {
        guard ttl > 0, capacity > 0 else { return }
        if entries.count >= capacity {
            let now = Date()
            entries = entries.filter { $0.value.expires > now }
            if entries.count >= capacity, let oldest = entries.min(by: { $0.value.expires < $1.value.expires })?.key { entries[oldest] = nil }
        }
        entries[url] = Entry(data: data, expires: Date().addingTimeInterval(ttl))
    }

    func clear() { entries.removeAll() }
}
