//
//  RichTextView-tvOS.swift
//  Pulse
//
//  Created by seunghwan Lee on 12/1/24.
//

import SwiftUI
import Pulse
 
#if os(tvOS)
extension NSAttributedString {
    func components(separatedBy string: String) -> [NSAttributedString] {
        var pos = 0
        return self.string.components(separatedBy: string).map {
            let range = NSRange(location: pos, length: $0.count)
            pos += range.length + string.count
            return self.attributedSubstring(from: range)
        }
    }
}

struct RichTextView: View {
    let viewModel: RichTextViewModel
    @FocusState private var focusedIndex: Int?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack {
                if let attributedStrings = viewModel.attributedStrings {
                    ForEach(attributedStrings.indices, id: \.self) { index in
                        Text(attributedStrings[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focusable()
                            .focused($focusedIndex, equals: index)
                            .background(focusedIndex == index && index != 0 ? Color.secondary : Color.clear)
                    }
                } else {
                    let strings = viewModel.strings
                    ForEach(strings.indices, id: \.self) { index in
                        Text(strings[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focusable()
                            .focused($focusedIndex, equals: index)
                            .background(focusedIndex == index && index != 0 ? Color.secondary : Color.clear)
                    }
                }
            }
        }
    }
}

final class RichTextViewModel: ObservableObject {
    let strings: [String]
    let attributedStrings: [AttributedString]?

    var isLinkDetectionEnabled = true
    var isEmpty: Bool { strings.isEmpty }

    init(string: String) {
        self.strings = string.components(separatedBy: "\n")
        self.attributedStrings = nil
    }

    init(string: NSAttributedString, contentType: NetworkLogger.ContentType? = nil) {
        self.strings = string.string.components(separatedBy: "\n")
        self.attributedStrings = string.components(separatedBy: "\n").compactMap { try? AttributedString($0, including: \.uiKit) }
    }
}
#endif
