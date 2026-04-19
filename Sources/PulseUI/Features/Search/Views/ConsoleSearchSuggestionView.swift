// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleSearchSuggestionView: View {
    package let suggestion: ConsoleSearchSuggestion
    package let action: (ConsoleSearchSuggestion) -> Void

    package init(suggestion: ConsoleSearchSuggestion, action: @escaping (ConsoleSearchSuggestion) -> Void) {
        self.suggestion = suggestion
        self.action = action
    }

    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    package var body: some View {
        switch suggestion.action {
        case .applyTerm(let term):
            termView(term)
        case .applyFilter(let filter):
            filterView(filter)
        }
    }

    // MARK: Term

    private func termView(_ term: ConsoleSearchTerm) -> some View {
        Button(action: { action(suggestion) }) {
            HStack(spacing: 6) {
                suggestionIcon("magnifyingglass")
                (Text(term.options.title + " ").foregroundColor(.primary) +
                 Text(term.text).foregroundColor(.accentColor))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, -2)
        }
    }

    // MARK: Filter

    private func filterView(_ filter: ConsoleSearchFilterSuggestion) -> some View {
        HStack(spacing: 6) {
            Button(action: { action(suggestion) }) {
                HStack(spacing: 6) {
                    suggestionIcon(filter.token.systemImage)
                    Text(filter.token.name)
                        .foregroundColor(.secondary)
                    highlightedValue(filter.token.valueDescription, searchText: filter.searchText)
                        .lineLimit(1)
                    Spacer()
                }
                .font(.callout)
            }
            if let draft = filter.makeCustomFilter() {
                Button {
                    viewModel.editingFilterState = .init(filter: draft, token: filter.token)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .frame(height: 16)
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func suggestionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .foregroundColor(.secondary)
            .font(.footnote)
            .frame(width: 16)
    }

    private func highlightedValue(_ value: String, searchText: String) -> Text {
        guard let range = value.range(of: searchText, options: .caseInsensitive) else {
            return Text(value).foregroundColor(.secondary)
        }
        let before = String(value[value.startIndex..<range.lowerBound])
        let matched = String(value[range])
        let after = String(value[range.upperBound...])
        return Text(before).foregroundColor(.secondary) +
                Text(matched).foregroundColor(.primary) +
               Text(after).foregroundColor(.secondary)
    }
}

#endif
