// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

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
    private(set) lazy var data = getData()
    private let getData: () -> Data

    @Published private(set) var contents: Contents?

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
        case json(RichTextViewModel)
        case image(ImagePreviewViewModel)
        case other(RichTextViewModel)
#if os(iOS) || os(macOS)
        case pdf(PDFDocument)
#endif
    }

    func render() {
        let data = self.data
        if data.count < 30_000 {
            self.contents = render(data: data)
        } else {
            Task.detached {
                let contents = self.render(data: data)
                Task { @MainActor in
                    withAnimation {
                        self.contents = contents
                    }
                }
            }
        }
    }

    private func render(data: Data) -> Contents {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return .json(.init(json: json, error: context.error))
        } else if let image = UXImage(data: data) {
            return .image(ImagePreviewViewModel(image: image, data: data, context: context))
        } else if let pdf = makePDF(data: data) {
            return pdf
        } else if data.isEmpty {
            return .other(.init(string: "Unavailable"))
        } else if let string = String(data: data, encoding: .utf8) {
#if os(iOS) || os(macOS)
            if contentType?.isEncodedForm ?? false, let components = decodeQueryParameters(form: string) {
                return .other(.init(string: components.asAttributedString()))
            } else if contentType?.isHTML ?? false {
                return .other(.init(string: HTMLPrettyPrint(string: string).render()))
            }
#endif
            return .other(.init(string: string))
        } else {
            let message = "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count)))"
            return .other(RichTextViewModel(string: message))
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

    private func decodeQueryParameters(form string: String) -> KeyValueSectionViewModel? {
        let string = "https://placeholder.com/path?" + string
        guard let components = URLComponents(string: string),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }
        return KeyValueSectionViewModel.makeQueryItems(for: queryItems, action: {})
    }
}

private extension Data {
    var localizedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count))
    }
}
