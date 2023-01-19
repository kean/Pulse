// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultView: View {
    let viewModel: ConsoleSearchResultViewModel
    var limit: Int = 4

    var body: some View {
        ConsoleEntityCell(entity: viewModel.entity)
        let occurences = Array(viewModel.occurences.enumerated()).filter {
            // TODO: these should be displayed inline
            $0.element.scope != .message && $0.element.scope != .url
        }
        ForEach(occurences.prefix(limit), id: \.offset) { item in
            NavigationLink(destination: makeDestination(for: item.element, entity: viewModel.entity)) {
                makeCell(for: item.element)
            }
        }
        if occurences.count > limit {
            NavigationLink(destination: ConsoleSearchResultDetailsView(viewModel: viewModel)) {
                HStack {
                    Text("Show All Results")
                        .font(ConsoleConstants.fontBody)
                    Text("\(occurences.count)")
                        .font(ConsoleConstants.fontBody)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // TODO: add occurence IDs instead of indices
    private func makeCell(for occurence: ConsoleSearchOccurence) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text(occurence.scope.fullTitle + " (\(occurence.line):\(occurence.range.lowerBound))")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
            Text(occurence.text)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    func makeDestination(for occurence: ConsoleSearchOccurence, entity: NSManagedObject) -> some View {
        _makeDestination(for: occurence, entity: entity)
            .environment(\.textViewSearchContext, occurence.searchContext)
    }

    @ViewBuilder
    func _makeDestination(for occurence: ConsoleSearchOccurence, entity: NSManagedObject) -> some View {
        if let task = entity as? NetworkTaskEntity {
            switch occurence.scope {
            case .url:
                NetworkDetailsView(title: "URL") {
                    TextRenderer(options: .sharing).make {
                        $0.render(task, content: .requestComponents)
                    }
                }
            case .queryItems:
                NetworkDetailsView(title: "URL") {
                    TextRenderer(options: .sharing).make {
                        $0.render(task, content: [.requestComponents, .requestQueryItems])
                    }
                }
            case .originalRequestHeaders:
                makeHeadersDetails(title: "Request Headers", headers: task.originalRequest?.headers)
            case .currentRequestHeaders:
                makeHeadersDetails(title: "Request Headers", headers: task.currentRequest?.headers)
            case .requestBody:
                NetworkInspectorRequestBodyView(viewModel: .init(task: task))
            case .responseHeaders:
                makeHeadersDetails(title: "Response Headers", headers: task.response?.headers)
            case .responseBody:
                NetworkInspectorResponseBodyView(viewModel: .init(task: task))
            case .message:
                EmptyView()
            }
        } else if let message = entity as? LoggerMessageEntity {
            ConsoleMessageDetailsView(viewModel: .init(message: message))
        }
    }

    private func makeHeadersDetails(title: String, headers: [String: String]?) -> some View {
        NetworkDetailsView(title: title) {
            KeyValueSectionViewModel.makeHeaders(title: title, headers: headers)
        }
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultDetailsView: View {
    let viewModel: ConsoleSearchResultViewModel

    var body: some View {
        List {
            ConsoleSearchResultView(viewModel: viewModel, limit: Int.max)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .inlineNavigationTitle("Search Results")
    }
}
