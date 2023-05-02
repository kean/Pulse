// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

#warning("how is this going to work for initial requests before the remote logger connects?")
final class URLSessionMockManager {
    private var mocks: [UUID: URLSessionMock] = [:]

    static let shared = URLSessionMockManager()

    func getMock(for request: URLRequest) -> URLSessionMock? {
        mocks.lazy.map(\.value).first {
            $0.isMatch(for: request)
        }
    }

    func update(_ request: URLSessionMockUpdateRequest) {
        for mockID in request.delete {
            mocks[mockID] = nil
        }
        for mock in request.update {
            mocks[mock.mockID] = mock
        }
    }
}

struct URLSessionMock: Codable {
    let mockID: UUID
    let url: String
    let isCaseSensitive: Bool
    let isRegex: Bool
    let method: String

    #warning("TODO: implement proper matching")
    func isMatch(for request: URLRequest) -> Bool {
        request.url?.absoluteString == url
    }
}

#warning("allow mocking errors? error code?")
struct URLSessionMockedResponse: Codable {
    let errorCode: Int?
    let statusCode: Int?
    let headers: [String: String]?
    var body: String?
}

#warning("test that errors are displayed corectly")
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

    #warning("test that error is displayed correctly")
    private func didReceiveResponse(_ response: URLSessionMockedResponse?) {
        guard let response = response else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown, userInfo: [
                NSLocalizedDescriptionKey: "Failed to retreive the mocked response"
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
        URLSessionMockManager.shared.getMock(for: request) != nil
    }
}
