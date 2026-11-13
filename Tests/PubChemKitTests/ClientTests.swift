import Testing
import Foundation
@testable import PubChemKit

@Suite struct ClientTests {
    @Test func aNameIsLookedUp() async throws {
        let transport = tetranitromethaneTransport()
        let client = PubChemClient(configuration: fastConfiguration, transport: transport)
        let c = try await client.compound(matching: "tetranitromethane")
        #expect(c.cid == 10509 && c.formula == "CN4O8")
        #expect(transport.urls.count == 1)
        #expect(transport.agents == ["PubChemKitTests"])
    }

    @Test func aRepeatedQueryComesFromTheCache() async throws {
        let transport = tetranitromethaneTransport()
        let client = PubChemClient(configuration: fastConfiguration, transport: transport)
        _ = try await client.compound(matching: "tetranitromethane")
        _ = try await client.compound(matching: "tetranitromethane")
        #expect(transport.urls.count == 1)
        await client.clearCache()
        _ = try await client.compound(matching: "tetranitromethane")
        #expect(transport.urls.count == 2)
    }

    @Test func anUnknownNameIsNotFound() async {
        let client = PubChemClient(configuration: fastConfiguration, transport: MockTransport { _ in (Data(#"{"Fault":{"Code":"PUGREST.NotFound"}}"#.utf8), 404) })
        await #expect(throws: PubChemError.notFound) { try await client.compound(matching: "zzqqxx") }
    }

    @Test func anEmptyQueryIsInvalidAndSendsNothing() async {
        let transport = tetranitromethaneTransport()
        let client = PubChemClient(configuration: fastConfiguration, transport: transport)
        await #expect(throws: PubChemError.invalidQuery) { try await client.compound(matching: "   ") }
        #expect(transport.urls.isEmpty)
    }

    @Test func aThrottledRequestIsRetriedOnce() async throws {
        let counter = Counter()
        let client = PubChemClient(configuration: fastConfiguration, transport: MockTransport { _ in
            counter.next() == 1 ? (Data(), 503) : (fixture("props"), 200)
        })
        let c = try await client.compound(matching: "tetranitromethane")
        #expect(c.cid == 10509)
        #expect(counter.value == 2)
    }

    @Test func aPersistentThrottleGivesUp() async {
        let counter = Counter()
        let client = PubChemClient(configuration: fastConfiguration, transport: MockTransport { _ in _ = counter.next(); return (Data(), 503) })
        await #expect(throws: PubChemError.rateLimited) { try await client.compound(matching: "tetranitromethane") }
        #expect(counter.value == 2)
    }

    @Test func otherStatusesAreReported() async {
        let client = PubChemClient(configuration: fastConfiguration, transport: MockTransport { _ in (Data(), 500) })
        await #expect(throws: PubChemError.unavailable(status: 500)) { try await client.compound(matching: "x") }
    }

    @Test func anOversizedAnswerIsRefused() async {
        var config = fastConfiguration
        config.maxResponseBytes = 100
        let client = PubChemClient(configuration: config, transport: tetranitromethaneTransport())
        await #expect(throws: PubChemError.badResponse) { try await client.compound(matching: "tetranitromethane") }
    }

    @Test func aFullLookupGathersProperties() async throws {
        let client = PubChemClient(configuration: fastConfiguration, transport: tetranitromethaneTransport())
        let r = try await client.lookup("tetranitromethane", includeDescription: true, includeHazards: true)
        #expect(r.compound.title == "Tetranitromethane")
        #expect(r.properties.map(\.section.label) == ["Melting point", "Boiling point", "Density", "Solubility"])
        #expect(r.description?.hasPrefix("Tetranitromethane can cause cancer") == true)
        #expect(r.hazards?.signalWord == "Danger")
    }

    @Test func descriptionAndHazardsAreOnlyFetchedWhenAsked() async throws {
        let transport = tetranitromethaneTransport()
        let client = PubChemClient(configuration: fastConfiguration, transport: transport)
        let r = try await client.lookup("tetranitromethane")
        #expect(r.description == nil && r.hazards == nil)
        #expect(!transport.urls.contains { $0.absoluteString.contains("GHS") || $0.absoluteString.contains("Record+Description") })
    }

    @Test func requestsAreSpacedByTheRateLimiter() async {
        let limiter = RateLimiter(requestsPerSecond: 20)
        let start = Date()
        for _ in 0..<5 { await limiter.wait() }
        #expect(Date().timeIntervalSince(start) >= 0.17)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}
