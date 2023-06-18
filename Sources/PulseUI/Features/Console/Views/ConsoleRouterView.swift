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
}

#if os(macOS)
enum ConsoleSelectedItem: Hashable {
    case entity(NSManagedObjectID)
    case occurrence(NSManagedObjectID, ConsoleSearchOccurrence)
}
#endif

struct ConsoleRouterView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var router: ConsoleRouter

    var body: some View {
        if #available(iOS 15, *) {
            contents
        }
    }
}

#if os(iOS)
@available(iOS 15, *)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
            .sheet(isPresented: $router.isShowingSessions) { destinationSessions }
            .sheet(isPresented: $router.isShowingStoreInfo) { destinationStoreInfo }
            .sheet(isPresented: $router.isShowingShareStore) { destinationShareStore }
            .sheet(item: $router.shareItems, content: ShareView.init)
    }
    
    private var destinationFilters: some View {
        NavigationView {
            ConsoleFiltersView()
                .inlineNavigationTitle("Filters")
                .navigationBarItems(trailing: Button("Done") {
                    router.isShowingFilters = false
                })
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    @ViewBuilder
    private var destinationSessions: some View {
        NavigationView {
            SessionsView()
                .navigationTitle("Sessions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button(action: { router.isShowingSessions = false }) {
                            Text("Close")
                        }
                    }
                }
        }
    }

    private var destinationSettings: some View {
        NavigationView {
            SettingsView(store: environment.store)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button(action: { router.isShowingSettings = false }) {
                    Text("Done")
                })
        }
    }

    private var destinationStoreInfo: some View {
        NavigationView {
            StoreDetailsView(source: .store(environment.store))
                .navigationBarItems(trailing: Button(action: { router.isShowingStoreInfo = false }) {
                    Text("Done")
                })
        }
    }

    private var destinationShareStore: some View {
        NavigationView {
            ShareStoreView(onDismiss: { router.isShowingShareStore = false })
        }.backport.presentationDetents([.medium, .large])
    }
}

#elseif os(watchOS)

extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingSettings) {
                NavigationView {
                    SettingsView(store: environment.store)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(action: {
                                    router.isShowingSettings = false
                                }, label: {
                                    Image(systemName: "xmark")
                                })
                            }
                        }
                }
            }
            .sheet(isPresented: $router.isShowingFilters) {
                NavigationView {
                    ConsoleFiltersView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(action: {
                                    router.isShowingFilters = false
                                }, label: {
                                    Image(systemName: "xmark")
                                })
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
