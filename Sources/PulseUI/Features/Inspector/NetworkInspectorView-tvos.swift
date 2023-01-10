// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

struct NetworkInspectorView: View {
    @ObservedObject var viewModel: NetworkInspectorViewModel

    @State private var isCurrentRequest = false

    var body: some View {
        contents
            .backport.inlineNavigationTitle(viewModel.title)
    }

    var contents: some View {
        HStack {
            Form {
                Section {
                    viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
                }
                Section {
                    requestTypePicker
                    NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
                } header: { Text("Request") }
                if viewModel.task.state != .pending {
                    Section {
                        NetworkInspectorSectionResponse(viewModel: viewModel)
                    } header: { Text("Response") }

                }
                Section { sectionMetrics } header: { Text("Transactions") }
            }
            .frame(width: 740)
            Form {
                Section {
                    transferStatusView.padding(.bottom, 32)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                NetworkInspectorMetricsViewModel(task: viewModel.task)
                    .map(NetworkInspectorMetricsView.init)
            }
        }
    }

    @ViewBuilder
    private var sectionMetrics: some View {
        NetworkCURLCell(task: viewModel.task)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var requestTypePicker: some View {
        Picker("Request Type", selection: $isShowingCurrentRequest) {
            Text("Original").tag(false)
            Text("Current").tag(true)
        }
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }
    }
}
#endif

#endif
