// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

package final class ConsoleRouter: ObservableObject {
#if os(macOS)
    @Published package var _selection: (any Hashable)?
#endif
    @Published package var shareItems: ShareItems?
    @Published package var isShowingFilters = false
    @Published package var isShowingSettings = false
    @Published package var isShowingSessions = false
    @Published package var isShowingShareStore = false

    package init() {}
}

#if os(macOS)
@available(macOS 15, *)
package enum ConsoleSelectedItem: Hashable {
    case entity(NSManagedObjectID)
    case occurrence(NSManagedObjectID, ConsoleSearchOccurrence)
}

@available(macOS 15, *)
extension ConsoleRouter {
    // Selection for macOS split-view navigation
    package var selection: ConsoleSelectedItem? {
        get { _selection as? ConsoleSelectedItem }
        set { _selection = newValue }
    }
}
#endif

struct ConsoleRouterView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @ObservedObject var router: ConsoleRouter

    var body: some View {
        if #available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *) {
            contents
        }
    }
}

#if os(iOS) || os(visionOS)
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
            .sheet(isPresented: $router.isShowingSessions) { destinationSessions }
            .sheet(isPresented: $router.isShowingShareStore) { destinationShareStore }
            .sheet(item: $router.shareItems, content: ShareView.init)
    }

    private var destinationFilters: some View {
        NavigationView {
            ConsoleFiltersView()
                .inlineNavigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        makeButton(role: .confirm) {
                            router.isShowingFilters = false
                        }
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var destinationSessions: some View {
        NavigationView {
            SessionsView()
                .navigationTitle("Sessions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        makeButton(role: .close) {
                            router.isShowingSessions = false
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var destinationSettings: some View {
        if let store = environment.store as? LoggerStore {
            NavigationView {
                SettingsView(store: store)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button(action: { router.isShowingSettings = false }) {
                        Text("Done")
                    })
            }
        }
    }

    private var destinationShareStore: some View {
        NavigationView {
            ShareStoreView(onDismiss: { router.isShowingShareStore = false })
        }.presentationDetents([.medium, .large])
    }
}

#elseif os(watchOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
            .sheet(isPresented: $router.isShowingSessions) { destinationSessions }
    }

    @ViewBuilder
    private var destinationSettings: some View {
        if let store = environment.store as? LoggerStore {
            NavigationView {
                SettingsView(store: store)
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
    }

    private var destinationFilters: some View {
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

    private var destinationSessions: some View {
        NavigationView {
            SessionsView()
                .navigationTitle("Sessions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: {
                            router.isShowingSessions = false
                        }, label: {
                            Image(systemName: "xmark")
                        })
                    }
                }
        }
    }
}

#elseif os(tvOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingSessions) { destinationSessions }
    }

    private var destinationSessions: some View {
        NavigationView {
            SessionsView()
                .navigationTitle("Sessions")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { router.isShowingSessions = false }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
    }
}

#else

@available(macOS 15, *)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
            .sheet(isPresented: $router.isShowingShareStore) { destinationShareStore }
    }

    private var destinationFilters: some View {
        ConsoleFiltersView()
            .frame(width: 320, height: 500)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { router.isShowingFilters = false }
                }
            }
    }

    private var destinationSettings: some View {
        SettingsView()
            .frame(width: 320, height: UserSettings.shared.isRemoteLoggingHidden ? 175 : 420)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.isShowingSettings = false }
                }
            }
    }

    private var destinationShareStore: some View {
        ShareStoreView(onDismiss: { router.isShowingShareStore = false })
            .frame(width: 340, height: 400)
    }
}

#endif
