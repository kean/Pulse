// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(tvOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store

    var body: some View {
        contents
            .inlineNavigationTitle(task.title)
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
            NetworkRequestStatusSectionView(viewModel: .init(task: task, store: store))
        }
        Section {
            NetworkInspectorRequestTypePicker(isCurrentRequest: $settings.isShowingCurrentRequest)
            NetworkInspectorView.makeRequestSection(task: task, isCurrentRequest: settings.isShowingCurrentRequest)
        } header: { Text("Request") }
        if task.state != .pending {
            Section {
                NetworkInspectorView.makeResponseSection(task: task)
            } header: { Text("Response") }

        }
        Section {
            NetworkCURLCell(task: task)
        } header: { Text("Transactions") }
    }

    @ViewBuilder
    private var rhs: some View {
        Section {
            NetworkInspectorView.makeHeaderView(task: task, store: store)
                .padding(.bottom, 32)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        NetworkInspectorMetricsViewModel(task: task)
            .map(NetworkInspectorMetricsView.init)
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
        }
    }
}
#endif

#endif
