// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

final class FileViewerViewModel: ObservableObject {
    let title: String
    private let getData: () -> Data

    @Published private(set) var contents: Contents?

    init(title: String, data: @escaping () -> Data) {
        self.title = title
        self.getData = data
    }

    enum Contents {
        case json(RichTextViewModel)
        case image(UXImage)
        case other(RichTextViewModel)
    }

    func render() {
        let data = getData()
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
            return .json(RichTextViewModel(json: json))
        } else if let image = UXImage(data: data) {
            return .image(image)
        } else if data.isEmpty {
            return .other(RichTextViewModel(string: "Unavailable"))
        } else {
            let string = String(data: data, encoding: .utf8) ?? "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
            return .other(RichTextViewModel(string: string))
        }
    }
}

private extension Data {
    var localizedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
