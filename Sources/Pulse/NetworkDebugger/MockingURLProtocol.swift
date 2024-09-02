// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A custom `URLProtocol` that enables Pulse network debugging features such
/// as mocking of the network responses.
public final class MockingURLProtocol: URLProtocol {
    public override func startLoading() {
        guard let mock = NetworkDebugger.shared.getMock(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown)) // Should never happen
            return
        }
        DispatchQueue.main.async {
            RemoteLogger.shared.getMockedResponse(for: mock) { [weak self] in
                self?.didReceiveResponse($0)
            }
        }
    }

    private func didReceiveResponse(_ response: URLSessionMockedResponse?) {
        guard let response = response else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown, userInfo: [
                NSLocalizedDescriptionKey: "Failed to retrieve the mocked response"
            ]))
            return
        }
        if let errorCode = response.errorCode.flatMap(URLError.Code.init) {
            client?.urlProtocol(self, didFailWithError: URLError(errorCode))
        } else {
            if let url = request.url, let response = HTTPURLResponse(url: url, statusCode: response.statusCode ?? 200, httpVersion: "HTTP/2.0", headerFields: response.headers) {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = response.body?.data(using: .utf8) {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    public override func stopLoading() {}

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        var request = request
        request.addValue("true", forHTTPHeaderField: MockingURLProtocol.requestMockedHeaderName)
        return request
    }

    public override class func canInit(with request: URLRequest) -> Bool {
        guard RemoteLogger.latestConnectionState.value == .connected else {
            return false
        }
        return NetworkDebugger.shared.shouldMock(request)
    }

    static let requestMockedHeaderName = "X-PulseRequestMocked"
}


// MARK: - MockingURLProtocol (Automatic Registration)

extension MockingURLProtocol {
    /// Inject the protocol in every `URLSession` instance created by the app.
    @MainActor
    public static func enableAutomaticRegistration() {
        if let lhs = class_getClassMethod(URLSession.self, #selector(URLSession.init(configuration:delegate:delegateQueue:))),
           let rhs = class_getClassMethod(URLSession.self, #selector(URLSession.pulse_init2(configuration:delegate:delegateQueue:))) {
            method_exchangeImplementations(lhs, rhs)
        }
    }
}

private extension URLSession {
    @objc class func pulse_init2(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue: OperationQueue?) -> URLSession {
        guard isConfiguringSessionSafe(delegate: delegate) else {
            return self.pulse_init2(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        return self.pulse_init2(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}
