// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A custom `URLProtocol` that enables Pulse network debugger features such
/// as mocking, request rewriting, breakpoints, and more.
public final class RemoteLoggerURLProtocol: URLProtocol {
    public override func startLoading() {
        guard let mock = URLSessionMockManager.shared.getMock(for: request) else {
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
        request.addValue("true", forHTTPHeaderField: RemoteLoggerURLProtocol.requestMockedHeaderName)
        return request
    }

    public override class func canInit(with request: URLRequest) -> Bool {
        URLSessionMockManager.shared.shouldMock(request)
    }

    static let requestMockedHeaderName = "X-PulseRequestMocked"
}
