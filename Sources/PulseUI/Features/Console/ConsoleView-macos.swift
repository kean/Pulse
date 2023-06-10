// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

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
            NavigationStack {
                ConsoleMainView(environment: environment)
            }
            .injecting(environment)
            .navigationTitle("")
        } else {
            PlaceholderView(imageName: "xmark.octagon", title: "Unsupported", subtitle: "Pulse requires iOS 15 or higher").padding()
        }
    }
}

/// This view contains the console itself along with the details (no sidebar).
@available(macOS 13, *)
private struct ConsoleMainView: View {
    let environment: ConsoleEnvironment

    @State private var isSharingStore = false
    @State private var isShowingFilters = false
    @State private var isShowingSessions = false
    @State private var isShowingSettings = false

    @SceneStorage("com-github-kean-pulse-is-now-enabled") private var isNowEnabled = true

    var body: some View {
        HSplitView {
            contentView
            detailsView.layoutPriority(1)
        }
    }

    private var contentView: some View {
        ConsoleListView()
            .frame(minWidth: 200, idealWidth: 400, minHeight: 120, idealHeight: 480)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    contentToolbarNavigationItems
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: { isShowingFilters = true }) {
                        Label("Show Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .popover(isPresented: $isShowingFilters) {
                        ConsoleFiltersView().frame(width: 300).fixedSize()
                    }
                    Button(action: { isShowingSessions = true }) {
                        Label("Show Sessions", systemImage: "list.clipboard")
                    }
                    .popover(isPresented: $isShowingSessions) {
                        SessionsView().frame(width: 300, height: 420)
                    }
                    Button(action: { isShowingSettings = true }) {
                        Label("Show Settings", systemImage: "gearshape")
                    }
                    .popover(isPresented: $isShowingSettings) {
                        SettingsView().frame(width: 300, height: 420)
                    }
                }
            }
    }

    private var detailsView: some View {
        _ConsoleDetailsView()
    }

    @ViewBuilder
    private var contentToolbarNavigationItems: some View {
        if !(environment.store.options.contains(.readonly)) {
            Toggle(isOn: $isNowEnabled) {
                Image(systemName: "clock")
            }
            Button(action: { isSharingStore = true }) {
                Image(systemName: "square.and.arrow.up")
            }
            .popover(isPresented: $isSharingStore, arrowEdge: .bottom) {
                ShareStoreView(onDismiss: {})
                    .frame(width: 240).fixedSize()
            }
            Button(action: { environment.store.removeAll() }) {
                Image(systemName: "trash")
            }
        }
    }
}

@available(iOS 15, macOS 13, *)
private struct _ConsoleDetailsView: View {
    @EnvironmentObject private var router: ConsoleRouter

    var body: some View {
        if let selection = router.selection {
            ConsoleEntityDetailsRouterView(selection: selection)
                .background(Color(UXColor.textBackgroundColor))
                .frame(minWidth: 400, idealWidth: 700, minHeight: 120, idealHeight: 480)
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
