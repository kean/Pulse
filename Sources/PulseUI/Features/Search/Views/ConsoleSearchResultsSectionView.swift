// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

// TODO: fix an issue where text jumps when you type quickly

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultView: View {
    let viewModel: ConsoleSearchResultViewModel
    var limit: Int = 4

    var body: some View {
        ConsoleEntityCell(entity: viewModel.entity)
        // TODO: limit number of occurences of the same type (or only have one and display how many more?)
        let occurences = Array(viewModel.occurences.enumerated())
        ForEach(occurences.prefix(limit), id: \.offset) { item in
            NavigationLink(destination: makeDestination(for: item.element, entity: viewModel.entity)) {
                makeCell(for: item.element)
            }
        }
        if occurences.count > limit {
            // TODO: how to prioritize what makes the cut?
            NavigationLink(destination: ConsoleSearchResultDetailsView(viewModel: viewModel)) {
                HStack {
                    Text("Show All Occurences")
                        .font(ConsoleConstants.fontBody)
                        .foregroundColor(.secondary)
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
            Text(occurence.kind.title + " (\(occurence.line):\(occurence.range.lowerBound))")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
            Text(occurence.text)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    func makeDestination(for occurence: ConsoleSearchOccurence, entity: NSManagedObject) -> some View {
        if let task = entity as? NetworkTaskEntity {
            switch occurence.kind {
            case .originalRequestHeaders:
                makeHeadersDetails(title: "Request Headers", headers: task.originalRequest?.headers)
                    .environment(\.textViewSearchContext, occurence.searchContext)
            case .currentRequestHeaders:
                makeHeadersDetails(title: "Request Headers", headers: task.currentRequest?.headers)
                    .environment(\.textViewSearchContext, occurence.searchContext)
            case .requestBody:
                NetworkInspectorRequestBodyView(viewModel: .init(task: task))
                    .environment(\.textViewSearchContext, occurence.searchContext)
            case .responseHeaders:
                makeHeadersDetails(title: "Response Headers", headers: task.response?.headers)
                    .environment(\.textViewSearchContext, occurence.searchContext)
            case .responseBody:
                NetworkInspectorResponseBodyView(viewModel: .init(task: task))
                    .environment(\.textViewSearchContext, occurence.searchContext)
            }
        } else {
            EmptyView()
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
