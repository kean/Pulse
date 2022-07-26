// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#warning("TODO: optimize, why data lazy?")
final class FileViewerViewModel {
    let title: String
    private let getData: () -> Data

    lazy var contents: Contents = {
        let data = getData()
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return .json(RichTextViewModel(json: json))
        } else if let image = UXImage(data: data) {
            return .image(image)
        } else {
            let string = String(data: data, encoding: .utf8) ?? "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
            return .other(RichTextViewModel(string: string))
        }
    }()

    init(title: String, data: @escaping () -> Data) {
        self.title = title
        self.getData = data
    }

    enum Contents {
        case json(RichTextViewModel)
        case image(UXImage)
        case other(RichTextViewModel)
    }
}

private extension Data {
    var localizedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
