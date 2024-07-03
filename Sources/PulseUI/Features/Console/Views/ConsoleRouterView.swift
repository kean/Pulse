// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)
public extension Notification.Name {
    static let selectNetworkConsoleEntity = Notification.Name("PulseUI.Console.Router.Select.Item")
}
#endif

final class ConsoleRouter: ObservableObject {
#if os(macOS)
    @Published var selection: ConsoleSelectedItem?
#endif
    @Published var shareItems: ShareItems?
    @Published var isShowingFilters = false
    @Published var isShowingSettings = false
    @Published var isShowingSessions = false
    @Published var isShowingShareStore = false
    
#if os(macOS)
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveSelectItemNotification), name: .selectNetworkConsoleEntity, object: nil)
    }
    
    @objc private func didReceiveSelectItemNotification(_ notification: Notification) {
        guard let managedObjectID = notification.object as? NSManagedObjectID else { return }
        selection = ConsoleSelectedItem.entity(managedObjectID)
    }
#endif
    
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

#if os(iOS) || os(visionOS)
@available(iOS 15, visionOS 1.0, *)
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
