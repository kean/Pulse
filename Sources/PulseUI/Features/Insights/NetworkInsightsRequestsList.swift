// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

#warning("reimplement")
struct NetworkInsightsRequestsList: View {
    @ObservedObject var viewModel: NetworkInsightsRequestsListViewModel

    public var body: some View {
        EmptyView()
//        ConsoleTableView(
//            header: { EmptyView() },
//            viewModel: viewModel.table,
//            detailsViewModel: viewModel.details
//        )
    }
}

final class NetworkInsightsRequestsListViewModel: ObservableObject {

    init(tasks: [NetworkTaskEntity]) {
//        self.table = ConsoleTableViewModel(searchCriteriaViewModel: nil)
//        self.table.entities = tasks
//        self.details = ConsoleDetailsRouterViewModel()
    }
}

#endif
