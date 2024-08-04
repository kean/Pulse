// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 15, visionOS 1, macOS 13, *)
struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @State private var shareItems: ShareItems?
    @State private var sharedTask: NetworkTaskEntity?
    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store

#if os(iOS) || os(visionOS)
    var body: some View {
        List {
            contents
        }
        .animation(.default, value: task.state)
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            OpenOnMacOverlay(entity: task)
        }
        .inlineNavigationTitle(ConsoleViewDelegate.getShortTitle(for: task))
        .sheet(item: $shareItems, content: ShareView.init)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                trailingNavigationBarItems
            }
        }
    }
#else
    var body: some View {
        List {
            contents
                .listRowSeparator(.hidden)
        }
        .scrollContentBackground(.hidden)
        .animation(.default, value: task.state)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                trailingNavigationBarItems
            }
        }
    }
#endif

    @ViewBuilder
    private var contents: some View {
        Section { NetworkInspectorView.makeHeaderView(task: task, store: store) }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        Section {
            NetworkRequestStatusSectionView(viewModel: .init(task: task, store: store))
        }
        Section {
            NetworkInspectorView.makeRequestSection(task: task, isCurrentRequest: settings.isShowingCurrentRequest)
        } header: { requestTypePicker }
        if task.state != .pending {
            Section {
                NetworkInspectorView.makeResponseSection(task: task)
            }
            Section {
                NetworkMetricsCell(task: task)
                NetworkCURLCell(task: task)
            }
        }
    }

    @ViewBuilder
    private var requestTypePicker: some View {
        HStack {
            Text("Request Type")
            Spacer()
            NetworkInspectorRequestTypePicker(isCurrentRequest: $settings.isShowingCurrentRequest)
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
#if os(iOS) || os(visionOS)
                .padding(.bottom, 4)
                .padding(.top, -10)
#endif
        }
    }

#if os(iOS) || os(visionOS)
    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        Menu(content: {
            AttributedStringShareMenu(shareItems: $shareItems) {
                TextRenderer(options: .sharing).make {
                    $0.render(task, content: .sharing, store: store)
                }
            }
            Button(action: { shareItems = ShareItems([task.cURLDescription()]) }) {
                Label("Share as cURL", systemImage: "square.and.arrow.up")
            }
        }, label: {
            Image(systemName: "square.and.arrow.up")
        })
        Menu(content: {
            ContextMenu.NetworkTaskContextMenuItems(task: task, sharedItems: $shareItems, isDetailsView: true)
        }, label: {
            Image(systemName: "ellipsis.circle")
        })
    }
#else
    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        Button(action: { sharedTask = task }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .popover(item: $sharedTask, attachmentAnchor: .point(.center), arrowEdge: .top) { ShareNetworkTaskView(task: $0) }
    }
#endif
}

#if DEBUG
@available(iOS 15, visionOS 1, macOS 13, *)
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
            }.previewDisplayName("Success")

            NavigationView {
                NetworkInspectorView(task: LoggerStore.preview.entity(for: .patchRepo))
            }.previewDisplayName("Failure")
        }
    }
}
#endif

#endif
