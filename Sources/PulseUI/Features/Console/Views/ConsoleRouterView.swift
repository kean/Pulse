// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

final class ConsoleRouter: ObservableObject {
    @Published var shareItems: ShareItems?
    @Published var isShowingAsText = false
    @Published var isShowingFilters = false
    @Published var isShowingSettings = false
    @Published var isShowingStoreInfo = false
    @Published var isShowingInsights = false
    @Published var isShowingShareStore = false
    @Published var isShowingDocumentBrowser = false
}

struct ConsoleRouterView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var router: ConsoleRouter

    var body: some View {
        Text("")
            .invisible()
            .sheet(item: $router.shareItems, content: ShareView.init)
            .sheet(isPresented: $router.isShowingAsText) { destinationTextView }
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
            .sheet(isPresented: $router.isShowingStoreInfo) { destinationStoreInfo }
            .sheet(isPresented: $router.isShowingShareStore) { destinationShareStore }
#if os(iOS)
            .sheet(isPresented: $router.isShowingInsights) { destinationInsights }
            .fullScreenCover(isPresented: $router.isShowingDocumentBrowser) { DocumentBrowser() }
#endif
    }

    private var destinationTextView: some View {
        NavigationView {
            ConsoleTextView(entities: viewModel.list.entitiesSubject) {
                viewModel.router.isShowingAsText = false
            }
        }
    }

    private var destinationFilters: some View {
        NavigationView {
            ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                .inlineNavigationTitle("Filters")
                .navigationBarItems(trailing: Button("Done") {
                    viewModel.router.isShowingFilters = false
                })
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

#if os(iOS)
    @ViewBuilder
    private var destinationInsights: some View {
        NavigationView {
            InsightsView(viewModel: viewModel.insightsViewModel)
                .navigationBarItems(trailing: Button(action: { router.isShowingInsights = false }) {
                    Text("Done")
                })
        }
    }
#endif
}

#if os(iOS)
import UniformTypeIdentifiers

private struct DocumentBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        DocumentBrowserViewController(forOpeningContentTypes: [UTType(filenameExtension: "pulse")].compactMap { $0 })
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {

    }
}
#endif
