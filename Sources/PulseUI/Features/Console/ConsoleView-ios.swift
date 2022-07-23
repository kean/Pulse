// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var shared: ShareItems?

    public init(store: LoggerStore = .default, configuration: ConsoleConfiguration = .default) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        contentView
            .navigationBarTitle(Text("Console"))
            .navigationBarItems(
                leading: viewModel.onDismiss.map {
                    Button(action: $0) { Image(systemName: "xmark") }
                },
                trailing: actionButton
            )
            .sheet(item: $shared) { ShareView($0).id($0.id) }

    }

    private var contentView: some View {
        ConsoleTableView(
            header: { ConsoleToolbarView(viewModel: viewModel) },
            viewModel: viewModel.table
        )
        .overlay(tableOverlay)
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.entities.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                if viewModel.configuration.isStoreSharingEnabled {
                    Section {
                        Button(action: { shared = viewModel.share(as: .store) }) {
                            Label("Share as Pulse Document", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { shared = viewModel.share(as: .text) }) {
                            Label("Share as Text File", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                Section {
                    ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
                        .disabled(viewModel.entities.isEmpty)
                        .opacity(viewModel.entities.isEmpty ? 0.33 : 1)
                }
            }, label: {
                Image(systemName: "ellipsis.circle")
            })
        } else {
            if viewModel.configuration.isStoreSharingEnabled {
                ShareButton { shared = viewModel.share(as: .store) }
            }
        }
    }
}

private struct ConsoleToolbarView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false
    @State private var messageCount = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                SearchBar(title: "Search \(viewModel.entities.count) messages", text: $viewModel.filterTerm)
                Button(action: { viewModel.isOnlyErrors.toggle() }) {
                    Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }.frame(width: 40, height: 44)
                Button(action: { isShowingFilters = true }) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }.frame(width: 40, height: 44)
            }.buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                ConsoleFiltersView(viewModel: viewModel.searchCriteria, isPresented: $isShowingFilters)
            }
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }.environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
