import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The one thing the client needs from the network. Inject your own in tests.
public protocol PubChemTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// A URLSession that follows no redirects, keeps no cookies and caches nothing.
public struct URLSessionTransport: PubChemTransport {
    private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    private let session: URLSession

    public init(timeout: TimeInterval = 10) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.httpCookieStorage = nil
        config.urlCache = nil
        self.session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
