// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
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

struct NetworkMessageContextMenu: View {
    let request: LoggerNetworkRequestEntity
    let store: LoggerStore

    @Binding private(set) var sharedItems: ShareItems?

    var body: some View {
        Section {
            if #available(iOS 14.0, *) {
                Menu("Share Request Log") {
                    shareAsButtons
                }
            } else {
                shareAsButtons
            }
            if let responseBodyKey = request.responseBodyKey {
                Button(action: {
                    sharedItems = ShareItems([store.getData(forKey: responseBodyKey) ?? Data()])
                }) {
                    Text("Share Response")
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        NetworkMessageContextMenuCopySection(request: request, shareService: ConsoleShareService(store: store))
        if let message = request.message {
            PinButton(viewModel: .init(store: store, message: message))
        }
    }

    @ViewBuilder
    private var shareAsButtons: some View {
        Button(action: {
            sharedItems = ShareItems([ConsoleShareService(store: store).share(request, output: .plainText)])
        }) {
            Text("Share as Plain Text")
            Image(systemName: "square.and.arrow.up")
        }
        Button(action: {
            let text = ConsoleShareService(store: store).share(request, output: .markdown)
            let directory = TemporaryDirectory()
            let fileURL = directory.write(text: text, extension: "markdown")
            sharedItems = ShareItems([fileURL], cleanup: directory.remove)
        }) {
            Text("Share as Markdown")
            Image(systemName: "square.and.arrow.up")
        }
        Button(action: {
            let text = ConsoleShareService(store: store).share(request, output: .html)
            let directory = TemporaryDirectory()
            let fileURL = directory.write(text: text, extension: "html")
            sharedItems = ShareItems([fileURL], cleanup: directory.remove)
        }) {
            Text("Share as HTML")
            Image(systemName: "square.and.arrow.up")
        }
        Button(action: {
            sharedItems = ShareItems([request.cURLDescription(store: store)])
        }) {
            Text("Share as cURL")
            Image(systemName: "square.and.arrow.up")
        }
    }
}

struct NetworkMessageContextMenuCopySection: View {
    var request: LoggerNetworkRequestEntity
    let shareService: ConsoleShareService

    var body: some View {
        Section {
            if let url = request.url {
                Button(action: {
                    UXPasteboard.general.string = url
                    runHapticFeedback()
                }) {
                    Text("Copy URL")
                    Image(systemName: "doc.on.doc")
                }
            }
            if let host = request.host {
                Button(action: {
                    UXPasteboard.general.string = host
                    runHapticFeedback()
                }) {
                    Text("Copy Host")
                    Image(systemName: "doc.on.doc")
                }
            }
            if let responseKey = request.responseBodyKey {
                Button(action: {
                    guard let data = shareService.store.getData(forKey: responseKey) else { return }
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

#if os(iOS) || os(macOS)
@available(iOS 14.0, *)
struct StringSearchOptionsMenu: View {
    @Binding private(set) var options: StringSearchOptions
    var isKindNeeded = true

    var body: some View {
        menu
    }

    var menu: some View {
        Menu(content: {
            Picker(options.isCaseSensitive ? "Case Sensitive" :  "Case Insensitive", selection: $options.isCaseSensitive) {
                Text("Case Sensitive").tag(true)
                Text("Case Insensitive").tag(false)
            }.pickerStyle(.inline)
            Picker(options.isRegex ? "Regular Expression" : "Text", selection: $options.isRegex) {
                Text("Text").tag(false)
                Text("Regular Expression").tag(true)
            }.pickerStyle(.inline)
            if !options.isRegex && isKindNeeded {
                Picker(options.kind.rawValue, selection: $options.kind) {
                    ForEach(StringSearchOptions.Kind.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }.pickerStyle(.inline)
            }
        }, label: {
            Image(systemName: "ellipsis.circle")
            #if os(iOS)
                .frame(width: 40, height: 44)
            #endif
        })
    }
}
#endif
