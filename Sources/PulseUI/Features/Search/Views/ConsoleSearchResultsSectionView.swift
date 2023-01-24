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
    var isSeparatorNeeded = false

    var body: some View {
        ConsoleEntityCell.make(for: viewModel.entity)
        let occurrences = Array(viewModel.occurrences.enumerated()).filter {
            // TODO: these should be displayed inline
            $0.element.scope != .message && $0.element.scope != .url
        }
        // TODO: add id instead of offset
        ForEach(occurrences.prefix(limit), id: \.offset) { item in
            NavigationLink(destination: makeDestination(for: item.element, entity: viewModel.entity)) {
                makeCell(for: item.element)
            }
        }
        if occurrences.count > limit {
            NavigationLink(destination: ConsoleSearchResultDetailsView(viewModel: viewModel)) {
                HStack {
                    Text("Show All Results")
                        .font(ConsoleConstants.fontBody)
                    Text("\(occurrences.count)")
                        .font(ConsoleConstants.fontBody)
                        .foregroundColor(.secondary)
                }
            }
        }
        if isSeparatorNeeded {
            PlainListGroupSeparator()
        }
    }

    @ViewBuilder
    private func makeCell(for occurrence: ConsoleSearchOccurrence) -> some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            Text(occurrence.scope.fullTitle + " (\(occurrence.line):\(occurrence.range.lowerBound))")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
            Text(occurrence.text)
                .lineLimit(3)
        }
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
    }

    @ViewBuilder
    func makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        _makeDestination(for: occurrence, entity: entity)
            .environment(\.textViewSearchContext, occurrence.searchContext)
    }

    @ViewBuilder
    private func _makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        if let message = entity as? LoggerMessageEntity {
            if let task = message.task {
                _makeDestination(for: occurrence, task: task)
            } else {
                ConsoleMessageDetailsView(viewModel: .init(message: message))
            }
        } else if let task = entity as? NetworkTaskEntity {
            _makeDestination(for: occurrence, task: task)
        } else {
            fatalError("Unsupported entity: \(entity)")
        }
    }

    @ViewBuilder
    private func _makeDestination(for occurrence: ConsoleSearchOccurrence, task: NetworkTaskEntity) -> some View {
        switch occurrence.scope {
        case .url:
            NetworkDetailsView(title: "URL") {
                TextRenderer(options: .sharing).make {
                    $0.render(task, content: .requestComponents)
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
        case .message, .metadata:
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

@available(iOS 15, tvOS 15, *)
struct PlainListGroupSeparator: View {
    var body: some View {
        Rectangle().foregroundColor(.clear) // DIY separator
            .frame(height: 12)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.separator.opacity(0.2))
#if os(iOS)
            .listRowSeparator(.hidden)
#endif
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListSectionHeader<Content: View>: View {
    var title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        contents
            .padding(.top, 8)
            .listRowBackground(Color.separator.opacity(0.2))
#if os(iOS)
            .listRowSeparator(.hidden)
#endif
    }

    @ViewBuilder
    private var contents: some View {
        if let title = title {
            HStack(alignment: .bottom, spacing: 0) {
                Text(title)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
        } else {
            content()
        }
    }
}

@available(iOS 15, tvOS 15, *)
extension PlainListSectionHeader where Content == Text {
    init(title: String) {
        self.init(title: title, content: { Text(title) })
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListExpandableSectionHeader<Destination: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let destination: () -> Destination
    var isSeeAllHidden = false

    var body: some View {
        PlainListSectionHeader {
            HStack(alignment: .bottom, spacing: 0) {
                Text(title)
                    .foregroundColor(.secondary)
                    .font(.subheadline.weight(.medium))
                +
                Text(" (\(count))")
                    .foregroundColor(.secondary.opacity(0.7))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                if !isSeeAllHidden {
                    Spacer()
                    Text("See All")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .background(NavigationLink("", destination: destination).opacity(0))
                }
            }
        }
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListSeeAllView: View {
    let count: Int

    var body: some View {
        (Text("See All").foregroundColor(.blue) +
         Text("  (\(count))"))
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListSectionHeaderSeparator: View {
    let title: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
    }
}
