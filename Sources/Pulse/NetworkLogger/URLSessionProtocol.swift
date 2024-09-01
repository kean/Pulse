// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

public protocol URLSessionProtocol {
    var sessionDescription: String? { get set }

    func finishTasksAndInvalidate()

    /// Cancels all outstanding tasks and then invalidates the session.
    ///
    /// Once invalidated, references to the delegate and callback objects are broken. After invalidation, session objects cannot be reused. To allow outstanding tasks to run until completion, call finishTasksAndInvalidate() instead.
    func invalidateAndCancel()

    func dataTask(with request: URLRequest) -> URLSessionDataTask

    func dataTask(with url: URL) -> URLSessionDataTask

    func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask

    func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask

    @available(iOS 17.0, *)
    func uploadTask(withResumeData resumeData: Data) -> URLSessionUploadTask

    func uploadTask(withStreamedRequest request: URLRequest) -> URLSessionUploadTask

    func downloadTask(with request: URLRequest) -> URLSessionDownloadTask

    func downloadTask(with url: URL) -> URLSessionDownloadTask

    func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask

    @available(iOS 9.0, *)
    func streamTask(withHostName hostname: String, port: Int) -> URLSessionStreamTask

    @available(iOS 13.0, *)
    func webSocketTask(with url: URL) -> URLSessionWebSocketTask

    @available(iOS 13.0, *)
    func webSocketTask(with url: URL, protocols: [String]) -> URLSessionWebSocketTask

    @available(iOS 13.0, *)
    func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask

    // MARK: - Closures

    /*
     * data task convenience methods.  These methods create tasks that
     * bypass the normal delegate calls for response and data delivery,
     * and provide a simple cancelable asynchronous interface to receiving
     * data.  Errors will be returned in the NSURLErrorDomain,
     * see <Foundation/NSURLError.h>.  The delegate, if any, will still be
     * called for authentication challenges.
     */
    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask

    func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask

    /*
     * upload convenience method.
     */
    func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask

    func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask

    /// Creates a URLSessionUploadTask from a resume data blob. If resuming from an upload
    /// file, the file must still exist and be unmodified.
    ///
    /// - Parameter resumeData: Resume data blob from an incomplete upload, such as data returned by the cancelByProducingResumeData: method.
    /// - Parameter completionHandler: The completion handler to call when the load request is complete.
    /// - Returns: A new session upload task, or nil if the resumeData is invalid.
    @available(iOS 17.0, *)
    func uploadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask

    /*
     * download task convenience methods.  When a download successfully
     * completes, the NSURL will point to a file that must be read or
     * copied during the invocation of the completion routine.  The file
     * will be removed automatically.
     */
    func downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask

    func downloadTask(with url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask

    func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask

    // MARK: - Combine

    /// Returns a publisher that wraps a URL session data task for a given URL.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task fails with an error.
    /// - Parameter url: The URL for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func dataTaskPublisher(for url: URL) -> URLSession.DataTaskPublisher

    /// Returns a publisher that wraps a URL session data task for a given URL request.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task fails with an error.
    /// - Parameter request: The URL request for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL request.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher

    // MARK: - Swift Concurrency

    /// Convenience method to load data using a URLRequest, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URL, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func data(from url: URL) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Returns: Data and response.
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
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

extension URLSession: URLSessionProtocol {}
