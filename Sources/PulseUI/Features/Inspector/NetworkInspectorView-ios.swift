// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

struct NetworkInspectorView: View {
    @StateObject var viewModel: NetworkInspectorViewModel

    @State private var shareItems: ShareItems?
    @State private var isCurrentRequest = false

    var body: some View {
        Form {
            contents
        }
        .inlineNavigationTitle(viewModel.title)
        .navigationBarItems(trailing: trailingNavigationBarItems)
        .sheet(item: $shareItems, content: ShareView.init)
    }

    @ViewBuilder
    private var contents: some View {
        Section { NetworkInspectorSectionTransferStatus(viewModel: viewModel) }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        Section {
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
        }
        Section {
            NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
        } header: { requestTypePicker }
        if viewModel.task.state != .pending {
            Section {
                NetworkInspectorSectionResponse(viewModel: viewModel)
            }
            Section {
                NetworkMetricsCell(task: viewModel.task)
                NetworkCURLCell(task: viewModel.task)
            }
        }
    }

    @ViewBuilder
    private var requestTypePicker: some View {
        HStack {
            Text("Request Type")
            Spacer()
            NetworkInspectorRequestTypePicker(isCurrentRequest: $isCurrentRequest)
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .padding(.bottom, 4)
                .padding(.top, -10)
        }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            Menu(content: {
                AttributedStringShareMenu(shareItems: $shareItems) {
                    TextRenderer(options: .sharing).make { $0.render(viewModel.task, content: .sharing) }
                }
                Button(action: { shareItems = ShareItems([viewModel.task.cURLDescription()]) }) {
                    Label("Share as cURL", systemImage: "square.and.arrow.up")
                }
            }, label: {
                Image(systemName: "square.and.arrow.up")
            })
            Menu(content: {
                NetworkMessageContextMenu(task: viewModel.task, sharedItems: $shareItems)
            }, label: {
                Image(systemName: "ellipsis.circle")
            })
        }
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            }.previewDisplayName("Success")

            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .patchRepo)))
            }.previewDisplayName("Failure")
        }
    }
}
#endif

#endif
