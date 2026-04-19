// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct NetworkRequestInfoCell: View {
    let viewModel: NetworkRequestInfoCellViewModel

    var body: some View {
        NavigationLink(destination: destinationRequestDetails) {
            contents
        }
    }

    private var contents: some View {
        (Text(viewModel.httpMethod).fontWeight(.semibold).font(.callout.smallCaps()) + Text(" ") + Text(viewModel.url))
            .lineLimit(4)
            .font(.callout)
    }

    private var destinationRequestDetails: some View {
        NetworkDetailsView(title: "Request") { viewModel.render() }
    }
}

package final class NetworkRequestInfoCellViewModel {
    package let httpMethod: String
    package let url: String
    package let render: () -> NSAttributedString

    package init(task: NetworkTaskEntity, store: LoggerStoreProtocol) {
        self.httpMethod = task.httpMethod ?? "GET"
        self.url = task.url ?? "–"
        self.render = {
            TextRenderer(options: .sharing).make {
                $0.render(task, content: .all, store: store)
            }
        }
    }

    package init(transaction: NetworkTransactionMetricsEntity) {
        self.httpMethod = transaction.request.httpMethod ?? "GET"
        self.url = transaction.request.url ?? "–"
        self.render = { TextRenderer(options: .sharing).make { $0.render(transaction) } }
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    NavigationView {
        List {
            ForEach(MockTask.allEntities, id: \.objectID) { task in
                NetworkRequestInfoCell(viewModel: .init(task: task, store: LoggerStore.mock))
            }
        }
#if os(macOS)
        .frame(width: 260)
#endif

    }
}
#endif
