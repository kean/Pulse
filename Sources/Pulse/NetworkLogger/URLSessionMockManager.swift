// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

// One more option is to add a delay on connection to make sure logger
// is connected before the app runs.
final class URLSessionMockManager {
    private var mocks: [UUID: URLSessionMock] = [:]

    static let shared = URLSessionMockManager()

    func getMock(for request: URLRequest) -> URLSessionMock? {
        mocks.lazy.map(\.value).first {
            $0.isMatch(for: request)
        }
    }

    func update(_ mocks: [URLSessionMock]) {
        self.mocks.removeAll()
        for mock in mocks {
            self.mocks[mock.mockID] = mock
        }
    }
}

final class URLSessionMockingProtocol: URLProtocol {
    override func startLoading() {
        guard let mock = URLSessionMockManager.shared.getMock(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown)) // Should never happen
            return
        }
        RemoteLogger.shared.getMockedResponse(for: mock) { [weak self] in
            self?.didReceiveResponse($0)
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

    override func stopLoading() {}

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override class func canInit(with request: URLRequest) -> Bool {
        URLSessionMockManager.shared.getMock(for: request) != nil && RemoteLogger.shared.connectionState == .connected
    }
}

extension URLSessionMock {
    func isMatch(for request: URLRequest) -> Bool {
        guard request.httpMethod?.uppercased() == method ?? "GET" else {
            return false
        }
        guard let url = request.url?.absoluteString else {
            return false
        }
        return isMatch(for: url)
    }

    func isMatch(for url: String) -> Bool {
        guard let regex = try? Regex(pattern, [.caseInsensitive]) else {
            return false
        }
        return regex.isMatch(url)
    }
}
