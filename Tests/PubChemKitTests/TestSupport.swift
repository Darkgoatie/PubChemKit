import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PubChemKit

func fixture(_ name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! Data(contentsOf: url)
}

func response(_ url: URL, status: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}

/// Answers from a closure and records every URL asked for.
final class MockTransport: PubChemTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _urls: [URL] = []
    private var _agents: [String] = []
    private let handler: @Sendable (URL) -> (Data, Int)

    init(_ handler: @escaping @Sendable (URL) -> (Data, Int)) { self.handler = handler }

    var urls: [URL] { lock.lock(); defer { lock.unlock() }; return _urls }
    var agents: [String] { lock.lock(); defer { lock.unlock() }; return _agents }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        lock.lock(); _urls.append(url); _agents.append(request.value(forHTTPHeaderField: "User-Agent") ?? ""); lock.unlock()
        let (data, status) = handler(url)
        return (data, response(url, status: status))
    }
}

/// Serves the recorded tetranitromethane answers by endpoint.
func tetranitromethaneTransport() -> MockTransport {
    MockTransport { url in
        let s = url.absoluteString
        if s.contains("/property/") { return (fixture("props"), 200) }
        if s.contains("heading=Melting") { return (fixture("melting"), 200) }
        if s.contains("heading=Boiling") { return (fixture("boiling"), 200) }
        if s.contains("heading=Density") { return (fixture("density"), 200) }
        if s.contains("heading=Solubility") { return (fixture("solubility"), 200) }
        if s.contains("heading=Physical") { return (fixture("physdesc"), 200) }
        if s.contains("heading=Record") { return (fixture("description"), 200) }
        if s.contains("heading=GHS") { return (fixture("ghs"), 200) }
        return (Data("{}".utf8), 404)
    }
}

var fastConfiguration: PubChemClient.Configuration {
    PubChemClient.Configuration(userAgent: "PubChemKitTests", requestsPerSecond: 1000, cacheTTL: 60, cacheCapacity: 50, retryDelay: 0.01)
}
