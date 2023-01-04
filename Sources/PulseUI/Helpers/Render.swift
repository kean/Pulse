// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Pulse
import Foundation

#if os(iOS) || os(macOS)

#warning("TODO: remove")
@available(*, deprecated, message: "Deprecated")
enum Render {
    static func asPlainText(task: NetworkTaskEntity) -> String {
        let renderer = TextRenderer(options: .init(networkContent: [.all]))
        let string = renderer.render(task)
        return string.string
    }

    static func asHTML(task: NetworkTaskEntity) -> String {
        let renderer = TextRenderer(options: .init(networkContent: [.all]))
        let string = renderer.render(task)
        guard let data = try? TextRenderer.html(from: string),
              let string = String(data: data, encoding: .utf8) else {
            return "Export Failed"
        }
        return string
    }
}

#endif
