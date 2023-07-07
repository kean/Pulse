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
            $0.isMatch(request)
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
        lock.lock()
        defer { lock.unlock() }

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

    override func stopLoading() {}

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let mock = URLSessionMockManager.shared.getMock(for: request) else {
            return false
        }
        defer { numberOfHandledRequests[mock.mockID, default: 0] += 1 }
        let count = numberOfHandledRequests[mock.mockID, default: 0]
        if count < (mock.skip ?? 0) {
            return false // Skip the first N requests
        }
        if let maxCount = mock.count, count - (mock.skip ?? 0) >= maxCount {
            return false // Mock for N number of times
        }
        return RemoteLogger.shared.connectionState == .connected
    }
}

// Number of handled requests per mock.
private var numberOfHandledRequests: [UUID: Int] = [:]
private let lock = NSLock()
