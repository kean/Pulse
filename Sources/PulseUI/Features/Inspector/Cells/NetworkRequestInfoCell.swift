// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkRequestInfoCell: View {
    let viewModel: NetworkRequestInfoCellViewModel

    var body: some View {
        NavigationLink(destination: destinationRequestDetails) {
            contents
        }
    }

    private var contents: some View {
        (Text(viewModel.httpMethod).bold() + Text(" ") + Text(viewModel.url))
            .lineLimit(4)
            .font(.callout)
    }

    private var destinationRequestDetails: some View {
        viewModel.requestDetailsViewModel.map(NetworkInspectorRequestDetailsView.init)
    }
}

final class NetworkRequestInfoCellViewModel {
    let httpMethod: String
    let url: String
    let requestDetailsViewModel: NetworkInspectorRequestDetailsViewModel?

    init(task: NetworkTaskEntity) {
        self.httpMethod = task.httpMethod ?? "GET"
        self.url = task.url ?? "–"
        self.requestDetailsViewModel = task.originalRequest.map(NetworkInspectorRequestDetailsViewModel.init)
    }

    init(request: NetworkRequestEntity) {
        self.httpMethod = request.httpMethod ?? "GET"
        self.url = request.url ?? "–"
        self.requestDetailsViewModel = NetworkInspectorRequestDetailsViewModel(request: request)
    }
}

#if DEBUG
struct NetworkRequestInfoCell_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(MockTask.allEntities, id: \.objectID) { task in
                    NetworkRequestInfoCell(viewModel: .init(task: task))
                }
            }
#if os(macOS)
            .frame(width: MainView.contentColumnWidth)
#endif
        }
    }
}
#endif
