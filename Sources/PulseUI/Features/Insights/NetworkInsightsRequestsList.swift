// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

struct NetworkInsightsRequestsList: View {
    @ObservedObject var viewModel: NetworkInsightsRequestsListViewModel

    public var body: some View {
        ConsoleTableView(
            header: { EmptyView() },
            viewModel: viewModel.table,
            detailsViewModel: viewModel.details
        )
    }
}

final class NetworkInsightsRequestsListViewModel: ObservableObject {
    let table: ConsoleTableViewModel
    let details: ConsoleDetailsRouterViewModel

    init(tasks: [NetworkTaskEntity]) {
        self.table = ConsoleTableViewModel(searchCriteriaViewModel: nil)
        self.table.entities = tasks
        self.details = ConsoleDetailsRouterViewModel()
    }
}

#endif
