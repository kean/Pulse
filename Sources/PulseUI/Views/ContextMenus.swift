// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

#if os(iOS) || os(macOS)

struct ButtonCopyMessage: View {
    let text: String

    var body: some View {
        Button(action: {
            UXPasteboard.general.string = text
            runHapticFeedback()
        }) {
            Text("Copy Message")
            Image(systemName: "doc.on.doc")
        }
    }
}

#warning("TODO: add share request")
#warning("TODO: fix sharing responseBody (share text)?")

struct NetworkMessageContextMenu: View {
    let task: NetworkTaskEntity

    @Binding private(set) var sharedItems: ShareItems?

    var body: some View {
        Section {
            if task.responseBodySize > 0 {
                Button(action: {
                    sharedItems = ShareItems([task.responseBody?.data ?? Data()])
                }) {
                    Text("Share Response")
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        NetworkMessageContextMenuCopySection(task: task)
        if let message = task.message {
            PinButton(viewModel: .init(message: message))
        }
    }
}

struct NetworkMessageContextMenuCopySection: View {
    var task: NetworkTaskEntity

    var body: some View {
        Section {
            if let url = task.url {
                Button(action: {
                    UXPasteboard.general.string = url
                    runHapticFeedback()
                }) {
                    Text("Copy URL")
                    Image(systemName: "doc.on.doc")
                }
            }
            if let host = task.host?.value {
                Button(action: {
                    UXPasteboard.general.string = host
                    runHapticFeedback()
                }) {
                    Text("Copy Host")
                    Image(systemName: "doc.on.doc")
                }
            }
            if task.responseBodySize > 0 {
                Button(action: {
                    guard let data = task.responseBody?.data else { return }
                    UXPasteboard.general.string = String(data: data, encoding: .utf8)
                    runHapticFeedback()
                }) {
                    Text("Copy Response")
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}
#endif

#warning("TODO: combine into one section + allow filering")

#if os(iOS) || os(macOS)
@available(iOS 14, *)
struct StringSearchOptionsMenu: View {
    @Binding private(set) var options: StringSearchOptions
    var isKindNeeded = true

    #if os(macOS)
    var body: some View {
        Menu(content: {
            contents
        }, label: {
            Image(systemName: "ellipsis.circle")
        })
        .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: false))
    }
    #else
    var body: some View {
        contents
    }
    #endif

    @ViewBuilder
    private var contents: some View {
        Toggle("Regular Expression", isOn: $options.isRegex)
        Toggle("Case Sensitive", isOn: $options.isCaseSensitive)
        pickerOptions
    }

    @ViewBuilder
    var pickerOptions: some View {
        if !options.isRegex && isKindNeeded {
            Picker(options.kind.rawValue, selection: $options.kind) {
                ForEach(StringSearchOptions.Kind.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

@available(iOS 14, *)
struct AttributedStringShareMenu: View {
    @Binding var shareItems: ShareItems?
    let string: () -> NSAttributedString

    var body: some View {
        Button(action: {
            shareItems = ShareItems([prepare().string])
        }) {
            Label("Share as Text", systemImage: "square.and.arrow.up")
        }
        Button(action: {
            let html = (try? TextRenderer.html(from: prepare())) ?? Data()
            let directory = TemporaryDirectory()
            let fileURL = directory.write(data: html, extension: "html")
            shareItems = ShareItems([fileURL], cleanup: directory.remove)
        }) {
            Text("Share as HTML")
            Image(systemName: "square.and.arrow.up")
        }
#if os(iOS)
        Button(action: {
            let pdf = (try? TextRenderer.pdf(from: prepare())) ?? Data()
            let directory = TemporaryDirectory()
            let fileURL = directory.write(data: pdf, extension: "pdf")
            shareItems = ShareItems([fileURL], cleanup: directory.remove)
        }) {
            Text("Share as PDF")
            Image(systemName: "square.and.arrow.up")
        }
#endif
    }

    private func prepare() -> NSAttributedString {
        let input = string()
        var ranges: [NSRange] = []
        input.enumerateAttribute(.isTechnicalKey, in: NSRange(location: 0, length: input.length)) { value, range, _ in
            if (value as? Bool) == true {
                ranges.append(range)
            }
        }
        print(ranges)

        let output = NSMutableAttributedString(attributedString: input)
        for range in ranges.reversed() {
            output.deleteCharacters(in: range)
        }
        return output
    }
}

#if DEBUG
@available(iOS 14, *)
struct StringSearchOptionsMenu_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            Menu(content: {
                Section(header: Label("Search Options", systemImage: "magnifyingglass")) {
                    StringSearchOptionsMenu(options: .constant(.default))
                }
            }) {
                Text("Menu")
            }
        }
    }
}
#endif

#endif
