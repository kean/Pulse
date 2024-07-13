// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        if #available(macOS 13, *) {
            NavigationSplitView(sidebar: {
                ConsoleMainView(environment: environment)
            }, detail: {
                NavigationStack {
                    Text("No Selection")
                }
            })
            .injecting(environment)
            .navigationTitle("")
        } else {
            PlaceholderView(imageName: "xmark.octagon", title: "Unsupported", subtitle: "Pulse requires macOS 13 or later").padding()
        }
    }
}

/// This view contains the console itself along with the details (no sidebar).
@available(macOS 13, *)
@MainActor
private struct ConsoleMainView: View {
    let environment: ConsoleEnvironment

    @State private var isSharingStore = false
    @State private var isShowingFilters = false

    @SceneStorage("com-github-kean-pulse-is-now-enabled") private var isNowEnabled = true

    @EnvironmentObject var router: ConsoleRouter

    var body: some View {
        ConsoleListView()
            .frame(minWidth: 400, idealWidth: 500, minHeight: 120, idealHeight: 480)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Toggle(isOn: $isNowEnabled) {
                        Image(systemName: "clock")
                    }.help("Now Mode: Automatically scrolls to the top of the view to display newly incoming network requests.")

                    Button(action: { isSharingStore = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Share a session")
                    .popover(isPresented: $isSharingStore, arrowEdge: .bottom) {
                        ShareStoreView(onDismiss: {})
                            .frame(width: 240).fixedSize()
                    }

                    Button(action: { isShowingFilters = true }) {
                        Label("Show Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .help("Show Filters")
                    .popover(isPresented: $isShowingFilters) {
                        ConsoleFiltersView().frame(width: 300).fixedSize()
                    }

                    ConsoleContextMenu()
                        .popover(isPresented: $router.isShowingSessions) {
                            SessionsView().frame(width: 300, height: 420)
                        }
                }
            }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleView(store: .mock)
            .previewLayout(.fixed(width: 700, height: 400))
    }
}
#endif
#endif
