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
        contents
            .injecting(environment)
            .navigationTitle("")
    }

    @ViewBuilder
    private var contents: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(sidebar: {
                ConsoleInspectorsView()
            }, detail: {
                NavigationStack {
                    ConsoleMainView(environment: environment)
                }
            })
        } else {
            NavigationView {
                ConsoleInspectorsView()
                ConsoleMainView(environment: environment)
            }
        }
    }
}

/// This view contains the console itself along with the details (no sidebar).
private struct ConsoleMainView: View {
    let environment: ConsoleEnvironment

    @State private var isSharingStore = false

    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false
    @AppStorage("com-github-kean-pulse-is-now-enabled") private var isNowEnabled = true

    var body: some View {
        if isVertical {
            VSplitView {
                contentView
                detailsView.layoutPriority(1)
            }
        } else {
            HSplitView {
                contentView
                detailsView.layoutPriority(1)
            }
        }
    }

    private var contentView: some View {
        ConsoleListView()
            .frame(minWidth: 200, idealWidth: 400, minHeight: 120, idealHeight: 480)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    contentToolbarNavigationItems
                }
            }
    }

    private var detailsView: some View {
        _ConsoleDetailsView(isVertical: $isVertical)
    }

    @ViewBuilder
    private var contentToolbarNavigationItems: some View {
        if !environment.store.isArchive {
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

private struct _ConsoleDetailsView: View {
    @Binding var isVertical: Bool

    @EnvironmentObject private var router: ConsoleRouter

    var body: some View {
        if let selection = router.selection {
            ConsoleEntityDetailsRouterView(selection: selection, isVertical: $isVertical)
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
