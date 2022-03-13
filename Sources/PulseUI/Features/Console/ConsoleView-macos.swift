// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)
struct ConsoleView: View {
    @ObservedObject private var model: ConsoleViewModel
    @State private var isShowingShareSheet = false
    @State private var isSearchBarActive = false

    init(model: ConsoleViewModel) {
        self.model = model
    }

    public var body: some View {
        ConsoleContentView(model: model, isSearchBarActive: $isSearchBarActive)
            .frame(minWidth: 270, idealWidth: 400, maxWidth: 700)
            .toolbar(content: {
                SearchBar(title: "Search", text: $model.searchTerm, onEditingChanged: { isSearchBarActive = $0 }, onReturn: model.nextMatch)
                // TODO: reimplement
//                Button(action: { isShowingShareSheet = true }) {
//                    Image(systemName: "square.and.arrow.up")
//                }
            })
            .background(ShareView(isPresented: $isShowingShareSheet) { model.share(as: .text).items })
    }
}

struct ConsoleContentView: View {
    @ObservedObject private(set) var model: ConsoleViewModel
    @Binding private(set) var isSearchBarActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isSearchBarActive || !model.matches.isEmpty {
                searchToolbar
            }
            ConsoleMessageListView(model: model)
            filtersToolbar
        }
    }

    private var searchToolbar: some View {
        VStack(spacing: 0) {
            HStack {
                StringSearchOptionsMenu(options: $model.searchOptions)
                    .fixedSize()

                Spacer()

                HStack(spacing: 4) {
                    Text(model.matches.isEmpty ? "0/0" : "\(model.selectedMatchIndex+1)/\(model.matches.count)")
                        .font(Font.body.monospacedDigit())
                    Button(action: model.previousMatch) {
                        Image(systemName: "chevron.left.circle")
                    }
                    Button(action: model.nextMatch) {
                        Image(systemName: "chevron.right.circle")
                    }
                }
                .fixedSize()

                Button("Done") {
                    model.doneSearch()
                    endEditing()
                }
            }
            .padding(10)

            Divider()
        }
    }

    private var filtersToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                SearchBar(title: "Filter", text: $model.filterTerm)
                    .frame(maxWidth: 200)
                Spacer()
            }.padding(10)
        }
        .frame(height: 40)
    }
}

private let messageViewId = NSUserInterfaceItemIdentifier(rawValue: "messageViewId")
private let requestViewId = NSUserInterfaceItemIdentifier(rawValue: "requestViewId")

struct ConsoleRowFactory {
    let context: AppContext
    var showInConsole: ((LoggerMessageEntity) -> Void)?

    func makeRowView(_ message: LoggerMessageEntity, _ tableView: NSTableView) -> NSView? {
        var show: (() -> Void)?
        if let showInConsole = showInConsole {
            show = { showInConsole(message) }
        }

        if let request = message.request {
            var view = tableView.makeView(withIdentifier: requestViewId, owner: nil) as? ConsoleNetworkRequestView
            if view == nil {
                view = ConsoleNetworkRequestView()
                view!.identifier = requestViewId
            }

            view!.display(.init(message: message, request: request, context: context, showInConsole: show))
            return view
        } else {
            var view = tableView.makeView(withIdentifier: messageViewId, owner: nil) as? ConsoleMessageView
            if view == nil {
                view = ConsoleMessageView()
                view!.identifier = messageViewId
            }

            view!.display(.init(message: message, context: context, showInConsole: show))
            return view
        }
    }
}

private func endEditing() {
    NSApp.keyWindow?.endEditing(for: nil)
}

#if DEBUG
@available(iOS 13.0, *)
struct ConsoleViewMac_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ConsoleView(model: .init(store: .mock))
            ConsoleView(model: .init(store: .mock))
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
