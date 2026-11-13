import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Talks to PubChem's PUG REST and PUG View services.
///
/// Requests are spaced to stay under PubChem's limit (5 per second), answers are cached in memory,
/// and a throttled request (HTTP 503 or 429) is retried once.
public actor PubChemClient {
    public struct Configuration: Sendable {
        /// Sent as the User-Agent header. Name your app and give a contact URL.
        public var userAgent: String
        public var requestsPerSecond: Double
        public var cacheTTL: TimeInterval
        public var cacheCapacity: Int
        public var maxResponseBytes: Int
        /// How long to wait before the single retry after a throttled request.
        public var retryDelay: TimeInterval

        public init(userAgent: String = "PubChemKit (https://github.com/Darkgoatie/PubChemKit)", requestsPerSecond: Double = 5,
                    cacheTTL: TimeInterval = 600, cacheCapacity: Int = 200, maxResponseBytes: Int = 3_000_000, retryDelay: TimeInterval = 1) {
            self.userAgent = userAgent
            self.requestsPerSecond = requestsPerSecond
            self.cacheTTL = cacheTTL
            self.cacheCapacity = cacheCapacity
            self.maxResponseBytes = maxResponseBytes
            self.retryDelay = retryDelay
        }
    }

    private let configuration: Configuration
    private let transport: PubChemTransport
    private let limiter: RateLimiter
    private let cache: ResponseCache

    public init(configuration: Configuration = Configuration(), transport: PubChemTransport = URLSessionTransport()) {
        self.configuration = configuration
        self.transport = transport
        self.limiter = RateLimiter(requestsPerSecond: configuration.requestsPerSecond)
        self.cache = ResponseCache(ttl: configuration.cacheTTL, capacity: configuration.cacheCapacity)
    }

    public func clearCache() async { await cache.clear() }

    // MARK: network

    private func fetch(_ url: URL?) async throws -> Data {
        guard let url, PubChemAPI.isAllowed(url) else { throw PubChemError.invalidQuery }
        if let cached = await cache.get(url) { return cached }
        var attempt = 0
        while true {
            await limiter.wait()
            var request = URLRequest(url: url)
            request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let data: Data
            let response: URLResponse
            do { (data, response) = try await transport.data(for: request) } catch { throw PubChemError.network(error.localizedDescription) }
            guard let http = response as? HTTPURLResponse else { throw PubChemError.badResponse }
            switch http.statusCode {
            case 200:
                guard data.count <= configuration.maxResponseBytes else { throw PubChemError.badResponse }
                await cache.set(url, data)
                return data
            case 404:
                throw PubChemError.notFound
            case 429, 503:
                attempt += 1
                if attempt > 1 { throw PubChemError.rateLimited }
                try? await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
            default:
                throw PubChemError.unavailable(status: http.statusCode)
            }
        }
    }

    // MARK: compounds

    /// The compounds that match a name, CAS number or formula, best first.
    /// Throws `PubChemError.notFound` when there are none.
    public func compounds(matching query: String) async throws -> [Compound] {
        let data = try await fetch(PubChemAPI.propertiesURL(for: query))
        let found = PubChemParser.compounds(from: data)
        if found.isEmpty { throw PubChemError.notFound }
        return found
    }

    /// The best match for a name, CAS number or formula.
    public func compound(matching query: String) async throws -> Compound {
        guard let first = try await compounds(matching: query).first else { throw PubChemError.notFound }
        return first
    }

    /// Names PubChem would complete the query to. Empty when there are none or the request fails.
    public func suggestions(for query: String, limit: Int = 5) async -> [String] {
        guard let data = try? await fetch(PubChemAPI.autocompleteURL(query, limit: limit)) else { return [] }
        return PubChemParser.suggestions(from: data)
    }

    // MARK: record sections

    /// The first value PubChem lists for a section, or nil when the record has none.
    public func value(for section: PropertySection, cid: Int, characterLimit: Int = 320) async throws -> String? {
        let data = try await fetch(PubChemAPI.recordURL(cid: cid, heading: section.heading))
        return PubChemParser.firstValue(from: data, heading: section.heading, limit: characterLimit)
    }

    /// The GHS classification of a compound, or nil when PubChem lists none.
    public func hazards(cid: Int) async throws -> Hazards? {
        let data = try await fetch(PubChemAPI.recordURL(cid: cid, heading: "GHS Classification"))
        return PubChemParser.hazards(from: data)
    }

    /// The given sections of a compound, fetched together. A section that is missing or fails is left out.
    public func properties(of compound: Compound, sections: [PropertySection] = PropertySection.standard) async -> [PropertyValue] {
        var found: [Int: PropertyValue] = [:]
        await withTaskGroup(of: (Int, PropertyValue?).self) { group in
            for (i, section) in sections.enumerated() {
                group.addTask { [self] in
                    guard let text = try? await self.value(for: section, cid: compound.cid) else { return (i, nil) }
                    return (i, PropertyValue(section: section, text: text))
                }
            }
            for await (i, value) in group { if let value { found[i] = value } }
        }
        return found.keys.sorted().compactMap { found[$0] }
    }

    /// A full lookup: the compound, its physical properties, and optionally its description and hazards.
    public func lookup(_ query: String, includeDescription: Bool = false, includeHazards: Bool = false,
                       sections: [PropertySection] = PropertySection.standard) async throws -> LookupResult {
        let matches = try await compounds(matching: query)
        let best = matches[0]
        async let props = properties(of: best, sections: sections)
        async let desc: String? = includeDescription ? (try? await value(for: .description, cid: best.cid)).flatMap { $0 } : nil
        async let haz: Hazards? = includeHazards ? (try? await hazards(cid: best.cid)).flatMap { $0 } : nil
        var properties = await props
        let description = await desc
        // PubChem often gives the same sentence as description and as appearance
        if let description { properties.removeAll { description == $0.text || description.hasPrefix(String($0.text.prefix(60))) } }
        return LookupResult(compound: best, otherMatches: Array(matches.dropFirst()), properties: properties, description: description,
                            hazards: await haz, requestedDescription: includeDescription, requestedHazards: includeHazards)
    }
}
