// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

@available(iOS 13.0, *)
public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var shared: ShareItems?

    @State private var isDetailsLinkActive = false
    @State private var selectedEntity: NSManagedObject?

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
            .background(invisibleNavigationLinks)
    }

    @ViewBuilder
    private var invisibleNavigationLinks: some View {
        NavigationLink(isActive: $isDetailsLinkActive, destination: { ConsoleMessageDetailsRouter(context: viewModel.context, entity: $selectedEntity) }, label: {  EmptyView() })
    }

    #warning("TEMP")
    private var contentView: some View {
        ConsoleTableView(
            header: { ConsoleToolbarView(viewModel: viewModel) },
            viewModel: viewModel.table,
            onSelected: {
                selectedEntity = $0
                isDetailsLinkActive = true
            }
        )

//        List {
//            ConsoleToolbarView(viewModel: viewModel)
//            if !viewModel.messages.isEmpty {
//                ConsoleMessagesForEach(context: viewModel.context, messages: viewModel.messages, searchCriteriaViewModel: viewModel.searchCriteria)
//            }
//        }
//        .listStyle(.plain)
        .background(background)
    }

    @ViewBuilder
    private var background: some View {
        if viewModel.messages.isEmpty {
            placeholder
        }
    }

    private var placeholder: PlaceholderView {
        let message: String
        if viewModel.searchCriteria.isDefaultSearchCriteria {
            if viewModel.searchCriteria.criteria.dates.isCurrentSessionOnly {
                message = "There are no messages in the current session."
            } else {
                message = "There are no stored messages."
            }
        } else {
            message = "There are no messages for the selected filters."
        }
        return PlaceholderView(imageName: "message", title: "No Messages", subtitle: message)
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
                        .disabled(viewModel.messages.isEmpty)
                        .opacity(viewModel.messages.isEmpty ? 0.33 : 1)
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

@available(iOS 13.0, *)
private struct ConsoleToolbarView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                SearchBar(title: "Search \(viewModel.messages.count) messages", text: $viewModel.filterTerm)
                Spacer().frame(width: 10)
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
        .padding(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 8))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                ConsoleFiltersView(viewModel: viewModel.searchCriteria, isPresented: $isShowingFilters)
            }
        }
    }
}

#if DEBUG
@available(iOS 13.0, *)
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ConsoleView(viewModel: .init(store: .mock))
            ConsoleView(viewModel: .init(store: .mock))
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
