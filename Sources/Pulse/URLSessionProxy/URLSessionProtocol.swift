// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

public protocol URLSessionProtocol {
    // MARK: - Core

    func dataTask(with request: URLRequest) -> URLSessionDataTask

    func dataTask(with url: URL) -> URLSessionDataTask

    func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask

    func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
    func uploadTask(withResumeData resumeData: Data) -> URLSessionUploadTask

    func uploadTask(withStreamedRequest request: URLRequest) -> URLSessionUploadTask

    func downloadTask(with request: URLRequest) -> URLSessionDownloadTask

    func downloadTask(with url: URL) -> URLSessionDownloadTask

    func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask

    func streamTask(withHostName hostname: String, port: Int) -> URLSessionStreamTask

    func webSocketTask(with url: URL) -> URLSessionWebSocketTask

    func webSocketTask(with url: URL, protocols: [String]) -> URLSessionWebSocketTask

    func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask

    // MARK: - Closures

    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask

    func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask

    func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask

    func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
    func uploadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask

    func downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask

    func downloadTask(with url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask

    func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask

    // MARK: - Combine

    func dataTaskPublisher(for url: URL) -> URLSession.DataTaskPublisher

    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher

    // MARK: - Swift Concurrency

    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    func upload(for request: URLRequest, fromFile fileURL: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    func upload(for request: URLRequest, from bodyData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    func download(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse)

    func download(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse)

    func download(resumeFrom resumeData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse)

    func bytes(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse)

    func bytes(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse)
}

public extension URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(from: url, delegate: nil)
    }

    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        try await upload(for: request, fromFile: fileURL, delegate: nil)
    }

    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        try await upload(for: request, from: bodyData, delegate: nil)
    }

    func bytes(from url: URL) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await bytes(from: url, delegate: nil)
    }
}

extension URLSession: URLSessionProtocol {}
