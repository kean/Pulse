// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

import UniformTypeIdentifiers

public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isSharing = false
    @State private var isShowingSettings = false
    @State private var isShowingStoreInfo = false
    @State private var isDocumentBrowserPresented = false

    public init(store: LoggerStore = .shared) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        contentView
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitle(Text("Console"))
            .navigationBarItems(
                leading: viewModel.onDismiss.map {
                    Button(action: $0) { Image(systemName: "xmark") }
                },
                trailing: HStack {
                    ShareButton { isSharing = true }
                    if #available(iOS 14.0, *) {
                        contextMenu
                    }
                }
            )
            .sheet(isPresented: $isSharing) {
                if #available(iOS 14.0, *) {
                    NavigationView {
                        ShareStoreView(store: viewModel.store, isPresented: $isSharing)
                    }.backport.presentationDetents([.medium])
                } else {
                    ShareView(ShareItems(messages: viewModel.store))
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationView {
                    SettingsView(store: viewModel.store)
                        .navigationBarItems(trailing: Button(action: { isShowingSettings = false }) {
                            Text("Done")
                        })
                }
            }
            .sheet(isPresented: $isShowingStoreInfo) {
                if #available(iOS 14.0, *) {
                    NavigationView {
                        StoreDetailsView(source: .store(viewModel.store))
                            .navigationBarItems(trailing: Button(action: { isShowingStoreInfo = false }) {
                                Text("Done")
                            })
                    }
                }
            }
            .backport.fullScreenCover(isPresented: $isDocumentBrowserPresented) {
                if #available(iOS 14.0, *) {
                    DocumentBrowser()
                }
            }
    }

    @available(iOS 14.0, *)
    private var contextMenu: some View {
        Menu {
            Section {
                Button(action: { isShowingStoreInfo = true }) {
                    Label("Store Info", systemImage: "info.circle")
                }
                if !viewModel.store.isArchive {
                    Button(action: { isDocumentBrowserPresented = true }) {
                        Label("Browse Stores", systemImage: "doc")
                    }
                }
            }
            Section {
                Button(action: { isShowingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
            }
            if !viewModel.store.isArchive {
                Section {
                    if #available(iOS 15.0, *) {
                        Button(role: .destructive, action: buttonRemoveAllTapped) {
                            Label("Remove Message", systemImage: "trash")
                        }
                    } else {
                        Button(action: buttonRemoveAllTapped) {
                            Label("Remove Message", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var contentView: some View {
        ConsoleTableView(
            header: { ConsoleToolbarView(viewModel: viewModel) },
            viewModel: viewModel.table,
            detailsViewModel: viewModel.details
        )
        .overlay(tableOverlay)
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.entities.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }

    // MARK: Helpers

    private func buttonRemoveAllTapped() {
        viewModel.store.removeAll()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
#endif
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
                        .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
                }.frame(width: 40, height: 44)
                Button(action: { isShowingFilters = true }) {
                    Image(systemName: viewModel.searchCriteria.isDefaultSearchCriteria ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
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

@available(iOS 14.0, *)
private struct DocumentBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        DocumentBrowserViewController(forOpeningContentTypes: [UTType(filenameExtension: "pulse")].compactMap { $0 })
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {

    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(viewModel: .init(store: .mock))
        }
    }
}
#endif

#endif
