// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @State private var shareItems: ShareItems?
    @State private var sharedTask: NetworkTaskEntity?
    @ObservedObject private var settings: UserSettings = .shared
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    package init(task: NetworkTaskEntity) {
        self.task = task
    }

    package var body: some View {
        List {
            contents
        }
        .animation(.default, value: task.state)
#if os(iOS) || os(visionOS)
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            OpenOnMacOverlay(entity: task)
        }
#else
        .listStyle(.inset)
#endif
        .inlineNavigationTitle(environment.shortTitle(for: task))
        .sheet(item: $shareItems, content: ShareView.init)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                trailingNavigationBarItems
            }
        }
    }

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
        if let custom = environment.delegate?.console(inspectorViewFor: task) {
            custom
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
                .padding(.bottom, 4)
                .padding(.top, -10)
        }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
#if os(iOS) || os(visionOS)
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
            if let custom = environment.delegate?.console(contextMenuFor: task) {
                custom
            }
        }, label: {
            Image(systemName: "ellipsis")
        })
#else
        Menu(content: {
            ContextMenu.NetworkTaskContextMenuItems(task: task, sharedTask: $sharedTask, isDetailsView: true)
            if let custom = environment.delegate?.console(contextMenuFor: task) {
                custom
            }
        }, label: {
            Image(systemName: "ellipsis")
        })
#endif
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Success") {
    NavigationView {
        NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
    }
    .injecting(ConsoleEnvironment(store: LoggerStore.preview))
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Failure") {
    NavigationView {
        NetworkInspectorView(task: LoggerStore.preview.entity(for: .patchRepo))
    }
    .injecting(ConsoleEnvironment(store: LoggerStore.preview))
}
#endif

#endif
