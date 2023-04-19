// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)
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
#if os(iOS) || os(macOS)
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
            let viewModel = RichTextViewModel(string: string, contentType: contentType)
            viewModel.isLineNumberRulerEnabled = true
            viewModel.isFilterEnabled = true
            return .other(viewModel)
        }
    }

    private func makePDF(data: Data) -> Contents? {
#if os(iOS) || os(macOS)
        if let pdf = PDFDocument(data: data) {
            return .pdf(pdf)
        }
#endif
        return nil
    }
}
