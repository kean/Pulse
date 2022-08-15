// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(tvOS)

struct RichTextView: View {
    let viewModel: RichTextViewModel
    var onToggleExpanded: (() -> Void)?

    var body: some View {
        Text(viewModel.text)
    }
}

final class RichTextViewModel: ObservableObject {
    let text: String

    init(string: String) {
        self.text = string
    }

    init(string: NSAttributedString) {
        self.text = string.string
    }

    convenience init(json: Any, error: NetworkLogger.DecodingError?) {
        self.init(string: format(json: json))
    }
}

private func format(json: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) else {
        return ""
    }
    return String(data: data, encoding: .utf8) ?? ""
}

#endif
