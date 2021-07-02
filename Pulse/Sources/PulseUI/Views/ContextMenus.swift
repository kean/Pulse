// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine

#if os(iOS) || os(macOS)

#if os(iOS)
@available(iOS 13.0, *)
struct ConsoleMessageContextMenu: View {
    let message: LoggerMessageEntity
    let context: AppContext
    @Binding var isShowingShareSheet: Bool
    @Binding var searchCriteria: ConsoleSearchCriteria

    var body: some View {
        Section {
            Button(action: {
                isShowingShareSheet = true
            }) {
                Text("Share")
                Image(systemName: "square.and.arrow.up")
            }
            ButtonCopyMessage(text: message.text)
            Button(action: {
                searchCriteria.focusedLabel = message.label
            }) {
                Text("Focus \'\(message.label.capitalized)\'")
                Image(systemName: "eye")
            }
            Button(action: {
                searchCriteria.hiddenLabels.insert(message.label)
            }) {
                Text("Hide \'\(message.label.capitalized)\'")
                Image(systemName: "eye.slash")
            }.foregroundColor(.red)
        }
        Section {
            PinButton(model: .init(service: context.pins, objectID: message.objectID))
        }
    }
}
#endif

#if os(iOS) || os(macOS)
@available(iOS 13.0, *)
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
#endif

#if os(iOS)
@available(iOS 13.0, *)
struct NetworkMessageContextMenu: View {
    let message: LoggerMessageEntity
    let request: LoggerNetworkRequestEntity
    let context: AppContext

    #if os(iOS)
    @Binding private(set) var sharedItems: ShareItems?
    #endif

    var body: some View {
        #if os(iOS)
        Section {
            Button(action: {
                sharedItems = ShareItems([context.share.share(request, output: .plainText)])
            }) {
                Text("Share as Plain Text")
                Image(systemName: "square.and.arrow.up")
            }
            Button(action: {
                let text = context.share.share(request, output: .markdown)
                let directory = TemporaryDirectory()
                let fileURL = directory.write(text: text, extension: "markdown")
                sharedItems = ShareItems([fileURL], cleanup: directory.remove)
            }) {
                Text("Share as Markdown")
                Image(systemName: "square.and.arrow.up")
            }
            Button(action: {
                let text = context.share.share(request, output: .html)
                let directory = TemporaryDirectory()
                let fileURL = directory.write(text: text, extension: "html")
                sharedItems = ShareItems([fileURL], cleanup: directory.remove)
            }) {
                Text("Share as HTML")
                Image(systemName: "square.and.arrow.up")
            }
            Button(action: {
                let summary = NetworkLoggerSummary(request: request, store: context.store)
                sharedItems = ShareItems([summary.cURLDescription()])
            }) {
                Text("Share as cURL")
                Image(systemName: "square.and.arrow.up")
            }
        }
        #endif
        NetworkMessageContextMenuCopySection(request: request, shareService: context.share)
        PinButton(model: .init(service: context.pins, objectID: message.objectID))
    }
}
#endif

#if os(iOS) || os(macOS)
@available(iOS 13.0, *)
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
            #if os(macOS)
            Button(action: {
                let summary = NetworkLoggerSummary(request: request, store: shareService.store)
                UXPasteboard.general.string = summary.cURLDescription()
                runHapticFeedback()
            }) {
                Text("Copy cURL")
                Image(systemName: "square.and.arrow.up")
            }
            #endif
        }
    }
}

@available(iOS 14.0, *)
struct StringSearchOptionsMenu: View {
    @Binding private(set) var options: StringSearchOptions
    var isKindNeeded = true

    var body: some View {
        Menu(content: {
            Picker(options.isCaseSensitive ? "Case Sensitive" :  "Case Insensitive", selection: $options.isCaseSensitive) {
                Text("Case Sensitive").tag(true)
                Text("Case Insensitive").tag(false)
            }.pickerStyle(InlinePickerStyle())
            Picker(options.isRegex ? "Regular Expression" : "Text", selection: $options.isRegex) {
                Text("Text").tag(false)
                Text("Regular Expression").tag(true)
            }.pickerStyle(InlinePickerStyle())
            if !options.isRegex && isKindNeeded {
                Picker(options.kind.rawValue, selection: $options.kind) {
                    ForEach(StringSearchOptions.Kind.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }.pickerStyle(InlinePickerStyle())
            }
        }, label: {
            Image(systemName: "ellipsis.circle")
        })
    }
}
#endif

#endif
