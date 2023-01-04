// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(tvOS)

struct RichTextView: View {
    let viewModel: RichTextViewModel

    var body: some View {
        ScrollView {
            if #available(watchOS 8.0, tvOS 15.0, *), let string = viewModel.attributedString {
                Text(string)
            } else {
                Text(viewModel.text)
            }
        }
    }
}

final class RichTextViewModel: ObservableObject {
    let text: String

    @available(watchOS 8.0, tvOS 15.0, *)
    var attributedString: AttributedString? {
        _attributedString as? AttributedString
    }

    private var _attributedString: Any?

    var isEmpty: Bool { text.isEmpty }

    init(string: String) {
        self.text = string
    }

    init(string: NSAttributedString, contentType: NetworkLogger.ContentType? = nil) {
        if #available(watchOS 8.0, tvOS 15.0, *) {
            self._attributedString = try? AttributedString(string, including: \.uiKit)
        }
        self.text = string.string
    }

    convenience init(json: Any, error: NetworkLogger.DecodingError?) {
        let renderer = AttributedStringJSONRenderer(fontSize: FontSize.body, lineHeight: FontSize.body + 5)
        let printer = JSONPrinter(renderer: renderer)
        printer.render(json: json, error: error)
        self.init(string: renderer.make())
    }
}

private func format(json: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) else {
        return ""
    }
    return String(data: data, encoding: .utf8) ?? ""
}

#endif
