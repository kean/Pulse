// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS) || os(visionOS)

@available(iOS 16, visionOS 1, macOS 13, *)
struct ConsoleSearchResultView: View {
    let viewModel: ConsoleSearchResultViewModel
    var isSeparatorNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        ConsoleEntityCell(entity: viewModel.entity)
        ForEach(makeMatches(from: viewModel.occurrences)) { item in
            NavigationLink(destination: ConsoleSearchResultView.makeDestination(for: item.occurrence, entity: viewModel.entity).injecting(environment)) {
                makeCell(for: item)
            }
        }
        if isSeparatorNeeded {
            PlainListGroupSeparator()
        }
    }

    @ViewBuilder
    private func makeCell(for item: ConsoleSearchResultsItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(detailsFont)
                .foregroundColor(.secondary)
            Text(item.occurrence.preview)
                .font(contentFont)
                .lineLimit(3)
        }.padding(.vertical, 4)
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
        case .originalRequestHeaders, .currentRequestHeaders, .responseHeaders:
            EmptyView() // Reserved
        case .requestBody:
            NetworkInspectorRequestBodyView(viewModel: .init(task: task))
        case .responseBody:
            NetworkInspectorResponseBodyView(viewModel: .init(task: task))
        case .url, .message, .metadata:
            EmptyView()
        }
    }

    private var contentFont: Font {
        let baseSize = CGFloat(settings.listDisplayOptions.content.fontSize)
        return Font.system(size: baseSize * fontMultiplier)
    }

    private var detailsFont: Font {
        let baseSize = CGFloat(settings.listDisplayOptions.header.fontSize)
        return Font.system(size: baseSize * fontMultiplier).monospacedDigit()
    }
}

@available(iOS 16, visionOS 1, *)
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

@available(iOS 16, visionOS 1, *)
struct ConsoleSearchResultsItem: Identifiable {
    var id: ConsoleSearchOccurrence { occurrence }
    let totalCount: Int
    let occurrence: ConsoleSearchOccurrence

    var title: String {
        let suffix: String
        if totalCount == 1 {
            suffix = ""
        } else if totalCount < ConsoleSearchMatch.limit {
            suffix = " (\(totalCount) matches)"
        } else {
            // we know there is 6, showin
            suffix = " (\(ConsoleSearchMatch.limit-1)+ matches)"
        }
        return "\(occurrence.scope.title)\(suffix)"
    }
}

#endif

#if os(iOS) || os(visionOS) || os(macOS)

@available(iOS 16, visionOS 1, *)
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

@available(iOS 16, macOS 13, visionOS 1, *)
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

@available(iOS 16, macOS 13, visionOS 1, *)
extension PlainListSectionHeader where Content == Text {
    init(title: String) {
        self.init(title: title, content: { Text(title) })
    }
}

#endif
