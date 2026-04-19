// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchListContentView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
        ConsoleSearchDynamicSuggestionsListView()
        if viewModel.parameters.isEmpty {
            ConsoleListContentView(hidesPreviousSessionButton: true)
        } else {
            if viewModel.isNewResultsButtonShown {
                showNewResultsPromptView
            }
            ConsoleSearchResultsListContentView(viewModel: viewModel)
        }
    }

    @ViewBuilder private var showNewResultsPromptView: some View {
        Button(action: viewModel.buttonShowNewlyAddedSearchResultsTapped) {
            Text("Show \(viewModel.newResultsCount) New Results")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .listRowSeparator(.hidden)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchResultsListContentView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel
    @EnvironmentObject private var listViewModel: ConsoleListViewModel

    var body: some View {
        if !viewModel.isPerformingSearch && viewModel.results.isEmpty {
            ConsoleSearchEmptyResultsView(viewModel: viewModel)
        } else if let sections = listViewModel.sections, !sections.isEmpty {
            groupedResults(sections: sections)
        } else {
            flatResults
        }
        if !viewModel.isPerformingSearch && !viewModel.hasMore && !viewModel.results.isEmpty {
            exactResultsFooter
        }
        extendedResultsView
    }

    @ViewBuilder
    private var flatResults: some View {
        ForEach(viewModel.results) { result in
            ConsoleSearchResultView(viewModel: result)
                .onAppear { viewModel.didScroll(to: result) }
        }
    }

    @ViewBuilder
    private var exactResultsFooter: some View {
        Text("No more results")
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .center)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden, edges: .bottom)
    }

    @ViewBuilder
    private var extendedResultsView: some View {
        if viewModel.isPerformingExtendedSearch && viewModel.extendedResults.isEmpty {
            extendedSectionHeader()
        }
        if !viewModel.extendedResults.isEmpty {
            Section {
                ForEach(viewModel.extendedResults) { result in
                    ConsoleSearchResultView(viewModel: result)
                        .onAppear { viewModel.didScroll(to: result, isExtended: true) }
                }
            } header: {
                extendedSectionHeader()
            }
        }
    }

    private func extendedSectionHeader() -> some View {
        HStack(spacing: 6) {
            Text("In other sessions:")
                .foregroundColor(.secondary)
            if !viewModel.extendedResults.isEmpty {
                Text("\(viewModel.extendedResults.count)\(viewModel.hasMoreExtended ? "+" : "")")
                    .foregroundColor(.primary)
            }
            Spacer()
            Button("Apply", action: viewModel.searchInOtherSessions)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
        }
        .font(.callout)
        .padding(.vertical, -2)
        .padding(.top, 32)
    }

    @ViewBuilder
    private func groupedResults(sections: [NSFetchedResultsSectionInfo]) -> some View {
        let groups = makeGroups(sections: sections)
        ForEach(groups, id: \.name) { group in
            let isCollapsed = listViewModel.collapsedSections.contains(group.name)
            Section {
                if !isCollapsed {
                    ForEach(group.results) { result in
                        ConsoleSearchResultView(viewModel: result)
                            .onAppear { viewModel.didScroll(to: result) }
                    }
                }
            } header: {
                Button(action: { withAnimation { listViewModel.toggleSection(group.name) } }) {
                    HStack {
                        Text(group.displayName)
                        Text("\(group.results.count)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private struct ResultGroup {
        let name: String
        let displayName: String
        let results: [ConsoleSearchResultViewModel]
    }

    private func makeGroups(sections: [NSFetchedResultsSectionInfo]) -> [ResultGroup] {
        var idToSection: [NSManagedObjectID: String] = [:]
        for section in sections {
            for object in (section.objects as? [NSManagedObject]) ?? [] {
                idToSection[object.objectID] = section.name
            }
        }
        var resultsByName: [String: [ConsoleSearchResultViewModel]] = [:]
        for result in viewModel.results {
            if let name = idToSection[result.entity.objectID] {
                resultsByName[name, default: []].append(result)
            }
        }
        return sections.compactMap { section in
            guard let results = resultsByName[section.name], !results.isEmpty else {
                return nil
            }
            return ResultGroup(
                name: section.name,
                displayName: listViewModel.name(for: section),
                results: results
            )
        }
    }
}

#endif
