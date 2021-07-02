// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)
import UIKit

@available(iOS 13.0, *)
public struct ConsoleView: View {
    @ObservedObject var model: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var shared: ShareItems?

    public init(store: LoggerStore = .default) {
        self.model = ConsoleViewModel(store: store)
    }

    init(model: ConsoleViewModel) {
        self.model = model
    }

    public var body: some View {
        NavigationView {
            contentView
                .navigationBarTitle(Text("Console"))
                .navigationBarItems(
                    leading: model.onDismiss.map { Button("Close", action: $0) },
                    trailing: shareButton
                )

            PlaceholderView(imageName: "folder", title: "Select an Item", subtitle: "Please select an item from the list to view the details")
        }
        .sheet(item: $shared) { ShareView($0).id($0.id) }
    }

    private var contentView: some View {
        List {
            QuickFiltersView(model: model)
            ConsoleMessagesForEach(context: model.context, messages: model.messages, searchCriteria: $model.searchCriteria)
        }.listStyle(PlainListStyle())
    }

    @ViewBuilder
    private var shareButton: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                Button(action: { shared = model.share(as: .store) }) {
                    Label("Share as File", systemImage: "square.and.arrow.up")
                }
                Button(action: { shared = model.share(as: .text) }) {
                    Label("Share as Text", systemImage: "square.and.arrow.up")
                }
            }, label: {
                Image(systemName: "square.and.arrow.up")
            })
        } else {
            ShareButton { shared = model.share(as: .store) }
        }
    }
}

@available(iOS 13, *)
private struct QuickFiltersView: View {
    @ObservedObject var model: ConsoleViewModel
    @State private var isShowingFilters = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                SearchBar(title: "Search \(model.messages.count) messages", text: $model.filterTerm)
                Button(action: {
                    isShowingFilters = true
                }) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .foregroundColor(Color.blue)
                }.buttonStyle(PlainButtonStyle())
            }
            ConsoleQuickFiltersView(filters: model.quickFilters)
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .sheet(isPresented: $isShowingFilters) {
            ConsoleFiltersView(searchCriteria: $model.searchCriteria, isPresented: $isShowingFilters)
        }
    }
}

#if DEBUG
@available(iOS 13.0, *)
struct ConsoleView_Previews: PreviewProvider {
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
