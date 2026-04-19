// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchDynamicSuggestionsListView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel
    @State private var isShowingAllRecents = false

    var body: some View {
        let suggestions = viewModel.suggestionsViewModel!
        if !suggestions.searches.isEmpty {
            recentSearchesRow(Array(suggestions.searches.prefix(3)))
        }
        makeList(with: suggestions.filters)
    }

    private func recentSearchesRow(_ searches: [ConsoleSearchSuggestion]) -> some View {
        SuggestionPills {
            ForEach(searches) { suggestion in
                if case .applyTerm(let term) = suggestion.action {
                    SuggestionPill(term.text) {
                        viewModel.perform(suggestion)
                    }
                    .frame(maxWidth: 140)
                }
            }
            Button(action: { isShowingAllRecents = true }) {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .strokeBorder(Color(.secondaryLabel).opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            }
            .buttonStyle(.plain)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .sheet(isPresented: $isShowingAllRecents) {
            ConsoleSearchRecentSearchesView()
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    private func makeList(with suggestions: [ConsoleSearchSuggestion]) -> some View {
        ForEach(suggestions) { suggestion in
            ConsoleSearchSuggestionView(suggestion: suggestion) { updatedSuggestion in
                viewModel.perform(updatedSuggestion)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct ConsoleSearchRecentSearchesView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Recent Searches")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            viewModel.buttonClearRecentSearchesTapped()
                            dismiss()
                        }
                        .disabled(viewModel.recentSearches.isEmpty)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let searches = viewModel.recentSearches
        if searches.isEmpty {
            ContentUnavailableView(
                "No Recent Searches",
                systemImage: "magnifyingglass",
                description: Text("Searches you perform will appear here.")
            )
        } else {
            List {
                ForEach(searches) { term in
                    Button(action: { perform(term) }) {
                        row(for: term)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeRecentSearch(term)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeRecentSearch(term)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(for term: ConsoleSearchTerm) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(term.text)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(term.options.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func perform(_ term: ConsoleSearchTerm) {
        viewModel.perform(ConsoleSearchSuggestion(action: .applyTerm(term)))
        dismiss()
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    let environment = ConsoleEnvironment(store: LoggerStore.mock)
    List {
        ConsoleSearchDynamicSuggestionsListView()
    }
    .listStyle(.plain)
    .injecting(environment)
    .environmentObject(ConsoleSearchViewModel(environment: environment, searchBar: .init()))
    .frame(width: 340)
}
#endif

#endif
