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
    var limit: Int = 4
    var isSeparatorNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        ConsoleEntityCell(entity: viewModel.entity)
        let occurrences = Array(viewModel.occurrences).filter { $0.scope.isDisplayedInResults }
        ForEach(occurrences.prefix(limit)) { item in
            NavigationLink(destination: ConsoleSearchResultView.makeDestination(for: item, entity: viewModel.entity).injecting(environment)) {
                makeCell(for: item)
            }
        }
        if occurrences.count > limit {
            let total = occurrences.count > ConsoleSearchMatch.limit ? "\(ConsoleSearchMatch.limit)+" : "\(occurrences.count)"
            NavigationLink(destination: ConsoleSearchResultDetailsView(viewModel: viewModel).injecting(environment)) {
                Text("Total Results: ")
                    .font(.callout) +
                Text(total)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        if isSeparatorNeeded {
            PlainListGroupSeparator()
        }
    }

    @ViewBuilder
    private func makeCell(for occurrence: ConsoleSearchOccurrence) -> some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            Text(occurrence.preview)
                .font(contentFont)
                .lineLimit(3)
            Text(occurrence.scope.title + " (\(occurrence.line):\(occurrence.range.lowerBound + 1))")
                .font(detailsFont)
                .foregroundColor(.secondary)
        }
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
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
