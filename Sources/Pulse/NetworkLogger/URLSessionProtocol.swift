// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

public protocol URLSessionProtocol {
    /// Convenience method to load data using a URLRequest, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Returns: Data and response.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URL, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Returns: Data and response.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func data(from url: URL) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Returns: Data and response.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Returns: Data and response.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URLRequest, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URL, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func upload(for request: URLRequest, fromFile fileURL: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func upload(for request: URLRequest, from bodyData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}
