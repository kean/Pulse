// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS) || os(visionOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchResultView: View {
    let viewModel: ConsoleSearchResultViewModel

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        let matches = makeMatches(from: viewModel.occurrences)
        let urlMatch = viewModel.occurrences.first(where: { $0.scope == .url })?.match
        ConsoleEntityCell(entity: viewModel.entity).urlMatch(urlMatch)
            .tag(viewModel.entity.objectID)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: matches.isEmpty ? 12 : 6, trailing: 16))
        ForEach(matches) { item in
            NavigationLink(destination: ConsoleSearchResultView.makeDestination(for: item.occurrence, entity: viewModel.entity).injecting(environment)) {
                makeCell(for: item)
            }
            .listRowInsets(
                EdgeInsets(
                    top: item.id != matches.first?.id ? 3 : 3,
                    leading: 20,
                    bottom: item.id != matches.last?.id ? 3 : 9,
                    trailing: 12
                )
            )
            .listRowSeparator(.hidden, edges: .top)
        }
    }

    @ViewBuilder
    private func makeCell(for item: ConsoleSearchResultsItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.separator)
                .frame(width: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.caption)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(item.occurrence.preview)
                    .font(contentFont)
                    .lineLimit(2)
                    .truncationMode(.middle)

            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    static func makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        _makeDestination(for: occurrence, entity: entity)
            .environment(\.textViewSearchContext, occurrence.searchContext)
    }

    @ViewBuilder
    private static func _makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        switch LoggerEntity(entity) {
        case .message(let message):
            ConsoleMessageDetailsView(message: message)
        case .task(let task):
            _makeDestination(for: occurrence, task: task)
        }
    }

    @ViewBuilder
    private static func _makeDestination(for occurrence: ConsoleSearchOccurrence, task: NetworkTaskEntity) -> some View {
        switch occurrence.scope {
        case .requestHeaders, .responseHeaders:
            EmptyView() // Reserved
        case .requestBody:
            NetworkInspectorRequestBodyView(viewModel: .init(task: task))
        case .responseBody:
            NetworkInspectorResponseBodyView(viewModel: .init(task: task))
        case .url, .query, .message, .metadata:
            EmptyView()
        }
    }

    private var contentFont: Font {
        let baseSize = CGFloat(settings.listDisplayOptions.content.fontSize)
        return Font.system(size: baseSize * fontMultiplier)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private func makeMatches(from occurrences: [ConsoleSearchOccurrence]) -> [ConsoleSearchResultsItem] {
    var items: [ConsoleSearchResultsItem] = []
    var index = 0
    while index < occurrences.endIndex {
        let occurrence = occurrences[index]

        if !occurrence.scope.isDisplayedInResults {
            index += 1
            continue // Skip
        }

        // Count all occurences in this scope and skip to the end
        var counter = 1 // Already found one
        while (index+1) < occurrences.endIndex && occurrences[index+1].scope == occurrence.scope  {
            counter += 1
            index += 1 // Consume next
        }

        let item = ConsoleSearchResultsItem(totalCount: counter, occurrence: occurrence)
        items.append(item)
        index += 1
    }
    return items
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchResultsItem: Identifiable {
    var id: ConsoleSearchOccurrence { occurrence }
    let totalCount: Int
    let occurrence: ConsoleSearchOccurrence

    var caption: String {
        let suffix: String
        if totalCount == 1 {
            suffix = ""
        } else if totalCount < ConsoleSearchMatch.limit {
            suffix = " · \(totalCount) matches"
        } else {
            suffix = " · \(ConsoleSearchMatch.limit-1)+ matches"
        }
        let location = "(\(occurrence.line + 1):\(occurrence.range.location + 1))"
        return "\(occurrence.scope.title) \(location)\(suffix)"
    }
}

#endif

#if os(iOS) || os(visionOS) || os(macOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct PlainListGroupSeparator: View {
    package init() {}

    package var body: some View {
        Rectangle().foregroundColor(.clear) // DIY separator
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.separator.opacity(0.2))
            .listRowSeparator(.hidden)
            .frame(height: 12)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct PlainListSectionHeader<Content: View>: View {
    package var title: String?
    @ViewBuilder package let content: () -> Content

    package init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    package var body: some View {
        contents
            .padding(.top, 8)
            .listRowBackground(Color.separator.opacity(0.2))
            .listRowSeparator(.hidden)
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

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension PlainListSectionHeader where Content == Text {
    init(title: String) {
        self.init(title: title, content: { Text(title) })
    }
}

#endif
