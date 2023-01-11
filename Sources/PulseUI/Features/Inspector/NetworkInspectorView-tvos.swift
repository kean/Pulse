// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

struct NetworkInspectorView: View {
    @StateObject var viewModel: NetworkInspectorViewModel

    @State private var isCurrentRequest = false

    var body: some View {
        contents
            .inlineNavigationTitle(viewModel.title)
    }

    var contents: some View {
        HStack {
            Form { lhs }.frame(width: 740)
            Form { rhs }
        }
    }

    @ViewBuilder
    private var lhs: some View {
        Section {
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
        }
        Section {
            NetworkInspectorRequestTypePicker(isCurrentRequest: $isCurrentRequest)
            NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
        } header: { Text("Request") }
        if viewModel.task.state != .pending {
            Section {
                NetworkInspectorSectionResponse(viewModel: viewModel)
            } header: { Text("Response") }

        }
        Section {
            NetworkCURLCell(task: viewModel.task)
        } header: { Text("Transactions") }
    }

    @ViewBuilder
    private var rhs: some View {
        Section {
            NetworkInspectorSectionTransferStatus(viewModel: viewModel)
                .padding(.bottom, 32)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        NetworkInspectorMetricsViewModel(task: viewModel.task)
            .map(NetworkInspectorMetricsView.init)
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
