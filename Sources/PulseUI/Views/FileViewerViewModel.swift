// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

final class FileViewerViewModel: ObservableObject {
    let title: String
    let contentType: String?
    private(set) lazy var data = getData()
    private let getData: () -> Data

    @Published private(set) var contents: Contents?

    init(title: String, contentType: String?, data: @escaping () -> Data) {
        self.title = title
        self.contentType = contentType
        self.getData = data
    }

    enum Contents {
        case json(RichTextViewModel)
        case image(UXImage)
        case other(RichTextViewModel)
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
        let data = getData()
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return .json(.init(json: json))
        } else if let image = UXImage(data: data) {
            return .image(image)
        } else if data.isEmpty {
            return .other(.init(string: "Unavailable"))
        } else if let string = String(data: data, encoding: .utf8) {
            if contentType == "application/x-www-form-urlencoded", let components = decodeQueryParameters(form: string) {
                return .other(.init(string: components.asAttributedString()))
            } else {
                return .other(.init(string: string))
            }
        } else {
            let message = "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
            return .other(RichTextViewModel(string: message))
        }
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
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
