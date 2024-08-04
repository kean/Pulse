// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS) || os(visionOS)
import PDFKit
#endif

final class FileViewerViewModel: ObservableObject {
    let title: String
    private let context: Context
    var contentType: NetworkLogger.ContentType? { context.contentType }
    private let getData: () -> Data

    private(set) lazy var contents: Contents = render(data: getData())

    struct Context {
        var contentType: NetworkLogger.ContentType?
        var originalSize: Int64
        var metadata: [String: String]?
        var isResponse = true
        var error: NetworkLogger.DecodingError?
    }

    init(title: String, context: Context, data: @escaping () -> Data) {
        self.title = title
        self.context = context
        self.getData = data
    }

    enum Contents {
        case image(ImagePreviewViewModel)
        case other(RichTextViewModel)
#if os(iOS) || os(macOS) || os(visionOS)
        case pdf(PDFDocument)
#endif
    }

    private func render(data: Data) -> Contents {
        if contentType?.isImage ?? false, let image = UXImage(data: data) {
            return .image(ImagePreviewViewModel(image: image, data: data, context: context))
        } else if contentType?.isPDF ?? false, let pdf = makePDF(data: data) {
            return pdf
        } else {
            let string = TextRenderer().render(data, contentType: contentType, error: context.error)
            return .other(RichTextViewModel(string: string, contentType: contentType))
        }
    }

    private func makePDF(data: Data) -> Contents? {
#if os(iOS) || os(macOS) || os(visionOS)
        if let pdf = PDFDocument(data: data) {
            return .pdf(pdf)
        }
#endif
        return nil
    }
}

extension NetworkTaskEntity {
    var requestFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: originalRequest?.contentType,
            originalSize: requestBodySize,
            metadata: metadata,
            isResponse: false,
            error: nil
        )
    }

    var responseFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: response?.contentType,
            originalSize: responseBodySize,
            metadata: metadata,
            isResponse: true,
            error: decodingError
        )
    }

    /// - returns `nil` if the task is an unknown state. It may happen if the
    /// task is pending, but it's from the previous app run.
    func state(in store: LoggerStore) -> NetworkTaskEntity.State? {
        let state = self.state
        if state == .pending && self.session != store.session.id {
            return nil
        }
        return state
    }
}
