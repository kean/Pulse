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

    @available(iOS 17, tvOS 17, macOS 14, watchOS 9, *)
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
    @available(iOS 17, tvOS 17, macOS 14, watchOS 9, *)
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
    func dataTaskPublisher(for url: URL) -> URLSession.DataTaskPublisher

    /// Returns a publisher that wraps a URL session data task for a given URL request.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task fails with an error.
    /// - Parameter request: The URL request for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL request.
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher

    // MARK: - Swift Concurrency

    /// Convenience method to load data using a URLRequest, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Returns: Data and response.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URL, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Returns: Data and response.
    func data(from url: URL) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Returns: Data and response.
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Returns: Data and response.
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URLRequest, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URL, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    func upload(for request: URLRequest, fromFile fileURL: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to upload data using a URLRequest, creates and resumes a URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    func upload(for request: URLRequest, from bodyData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to download using a URLRequest, creates and resumes a URLSessionDownloadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to download.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    func download(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse)

    /// Convenience method to download using a URL, creates and resumes a URLSessionDownloadTask internally.
    ///
    /// - Parameter url: The URL for which to download.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    func download(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse)

    /// Convenience method to resume download, creates and resumes a URLSessionDownloadTask internally.
    ///
    /// - Parameter resumeData: Resume data from an incomplete download.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    func download(resumeFrom resumeData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse)

    /// Returns a byte stream that conforms to AsyncSequence protocol.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data stream and response.
    func bytes(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse)

    /// Returns a byte stream that conforms to AsyncSequence protocol.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data stream and response.
    func bytes(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse)
}

extension URLSession: URLSessionProtocol {}
