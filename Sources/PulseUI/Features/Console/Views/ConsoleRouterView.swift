// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

package final class ConsoleRouter: ObservableObject {
#if os(macOS)
    @Published package var selection: ConsoleSelectedItem?
#endif
    @Published package var shareItems: ShareItems?
    @Published package var isShowingFilters = false
    @Published package var isShowingSettings = false
    @Published package var isShowingSessions = false
    @Published package var isShowingShareStore = false

    package init() {}
}

#if os(macOS)
package enum ConsoleSelectedItem: Hashable {
    case entity(NSManagedObjectID)
    case occurrence(NSManagedObjectID, ConsoleSearchOccurrence)
}
#endif

struct ConsoleRouterView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var router: ConsoleRouter

    var body: some View {
        if #available(iOS 16, macOS 13, *) {
            contents
        }
    }
}

#if os(iOS) || os(visionOS)
@available(iOS 16, visionOS 1, *)
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

    private var destinationShareStore: some View {
        NavigationView {
            ShareStoreView(onDismiss: { router.isShowingShareStore = false })
        }.presentationDetents([.medium, .large])
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

@available(macOS 13, *)
extension ConsoleRouterView {
    var contents: some View {
        Text("").invisible()
            .sheet(isPresented: $router.isShowingSettings) { destinationSettings }
    }

    private var destinationSettings: some View {
        SettingsView()
            .frame(width: 320, height: UserSettings.shared.isRemoteLoggingHidden ? 175 : 420)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { router.isShowingSettings = false }) {
                        Text("Close")
                    }
                }
            }
    }
}

#endif
