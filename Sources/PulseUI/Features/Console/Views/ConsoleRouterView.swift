// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

final class ConsoleRouter: ObservableObject {
#if os(macOS)
    @Published var selection: ConsoleSelectedItem?
#endif
    @Published var shareItems: ShareItems?
    @Published var isShowingFilters = false
    @Published var isShowingSettings = false
    @Published var isShowingSessions = false
    @Published var isShowingStoreInfo = false
    @Published var isShowingShareStore = false
    @Published var isShowingDocumentBrowser = false
}

#if os(macOS)
enum ConsoleSelectedItem: Hashable {
    case entity(NSManagedObjectID)
    case occurrence(NSManagedObjectID, ConsoleSearchOccurrence)
}
#endif

struct ConsoleRouterView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var router: ConsoleRouter

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.router = viewModel.router
    }

    var body: some View {
        contents
    }
}

#if os(iOS)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
            .sheet(isPresented: $router.isShowingSessions) { destinationSessions }
            .sheet(isPresented: $router.isShowingStoreInfo) { destinationStoreInfo }
            .sheet(isPresented: $router.isShowingShareStore) { destinationShareStore }
            .sheet(item: $router.shareItems, content: ShareView.init)
            .fullScreenCover(isPresented: $router.isShowingDocumentBrowser) { DocumentBrowser() }
    }

    private var destinationFilters: some View {
        NavigationView {
            let view = ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                .inlineNavigationTitle("Filters")
                .navigationBarItems(trailing: Button("Done") {
                    viewModel.router.isShowingFilters = false
                })

            if #available(iOS 15, *) {
                view.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            } else {
                view
            }
        }
    }

    @ViewBuilder
    private var destinationSessions: some View {
        if #available(iOS 15, *) {
            NavigationView {
                ConsoleSessionsView()
                    .injectingEnvironment(viewModel)
                    .navigationTitle("Session")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button(action: { router.isShowingSessions = false }) {
                        Text("Done")
                    })
            }
        }
    }

    private var destinationSettings: some View {
        NavigationView {
            SettingsView(store: viewModel.store)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button(action: { router.isShowingSettings = false }) {
                    Text("Done")
                })
        }
    }

    private var destinationStoreInfo: some View {
        NavigationView {
            StoreDetailsView(source: .store(viewModel.store))
                .navigationBarItems(trailing: Button(action: { router.isShowingStoreInfo = false }) {
                    Text("Done")
                })
        }
    }

    private var destinationShareStore: some View {
        NavigationView {
            ShareStoreView(store: viewModel.store, isPresented: $router.isShowingShareStore)
        }.backport.presentationDetents([.medium])
    }
}

import UniformTypeIdentifiers

private struct DocumentBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        DocumentBrowserViewController(forOpeningContentTypes: [UTType(filenameExtension: "pulse")].compactMap { $0 })
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {

    }
}

#elseif os(watchOS)

extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingSettings) {
                NavigationView {
                    SettingsView(viewModel: .init(store: viewModel.store))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { router.isShowingSettings = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $router.isShowingFilters) {
                NavigationView {
                    ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { router.isShowingFilters = false }
                            }
                        }
                }
            }
    }
}

#else

extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
    }
}

#endif
