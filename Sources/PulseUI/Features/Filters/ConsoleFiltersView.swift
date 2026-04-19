// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleFiltersView: View {
    @EnvironmentObject var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var environment: ConsoleEnvironment

    @Environment(\.dismiss) var dismiss

    package init() {}

    package var body: some View {
#if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        Form {
            form
        }
        .animation(.snappy, value: viewModel.criteria)
#if os(iOS) || os(visionOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                buttonRecents
            }
        }
        .onDisappear { viewModel.snapshotRecentFilters() }
#endif
#else
        VStack(spacing: 0) {
            ScrollView {
                form
            }
            HStack {
                Text(viewModel.mode == .network ? "Network Filters" : "Message Filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34, alignment: .center)
        }
        .animation(.snappy, value: viewModel.criteria)
        .onDisappear { viewModel.snapshotRecentFilters() }
#endif
    }

#if os(iOS) || os(visionOS)
    @State private var isShowingRecents = false

    private var buttonRecents: some View {
        let store = viewModel.recentFiltersStore(for: viewModel.mode)
        return Button(action: { isShowingRecents = true }) {
            Text("Recents")
        }
        .disabled(store.recents.isEmpty)
        .sheet(isPresented: $isShowingRecents) {
            ConsoleRecentFiltersListView(store: store, mode: viewModel.mode) {
                viewModel.apply($0)
            }
            .presentationDetents([.medium, .large])
        }
    }
#endif

    @ViewBuilder
    private var form: some View {
#if os(tvOS) || os(watchOS)
        buttonReset
#endif

        if viewModel.mode == .network {
            responseSection
            requestSection
            customNetworkFiltersSection
            domainsSection
            networkingSection
        } else {
            customMessageFiltersSection
            logLevelsSection
            labelsSection
        }

#if os(iOS) || os(macOS) || os(visionOS)
        timePeriodSection
#endif

        buttonReset
    }

    private var buttonReset: some View {
        Button("Reset All", role: .destructive, action: viewModel.resetAll)
            .disabled(viewModel.isDefaultFilters(for: viewModel.mode))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - ConsoleFiltersView (Sections)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension ConsoleFiltersView {
#if os(iOS) || os(macOS) || os(visionOS)
    var timePeriodSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "calendar", title: "Time Period", filter: $viewModel.criteria.shared.dates)
        }, content: {
            ConsoleSearchTimePeriodCell(selection: $viewModel.criteria.shared.dates)
        })
    }
#endif

    var logLevelsSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "flag", title: "Levels", filter: $viewModel.criteria.messages.logLevels)
        }, content: {
            ConsoleSearchLogLevelsCell(selection: $viewModel.criteria.messages.logLevels.levels)
        })
    }

    var labelsSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "tag", title: "Labels", filter: $viewModel.criteria.messages.labels)
        }, content: {
            ConsoleLabelsSelectionView(viewModel: viewModel, index: environment.index)
        })
    }

    var domainsSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "server.rack", title: "Hosts", filter: $viewModel.criteria.network.host)
        }, content: {
            ConsoleDomainsSelectionView(viewModel: viewModel, index: environment.index)
        })
    }

    var customMessageFiltersSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.messages.custom) {
                ConsoleFilterLogicalOperatorPicker(
                    selection: $viewModel.criteria.messages.custom.logicalOperator,
                    activeFilterCount: viewModel.criteria.messages.custom.filters.filter({ !$0.value.isEmpty }).count
                )
            }
        }, content: {
            ConsoleSearchCustomFiltersSection(
                filters: $viewModel.criteria.messages.custom.filters,
                fieldGroups: ConsoleCustomFilter.messageFieldGroups,
                defaultFilter: .defaultMessageFilter()
            )
        })
    }

    var customNetworkFiltersSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.network.custom) {
                ConsoleFilterLogicalOperatorPicker(
                    selection: $viewModel.criteria.network.custom.logicalOperator,
                    activeFilterCount: viewModel.criteria.network.custom.filters.filter({ !$0.value.isEmpty }).count
                )
            }
        }, content: {
            ConsoleSearchCustomFiltersSection(
                filters: $viewModel.criteria.network.custom.filters,
                fieldGroups: ConsoleCustomFilter.networkFieldGroups,
                defaultFilter: .defaultNetworkFilter()
            )
        })
    }

    var responseSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "arrow.down.circle", title:  "Response", filter: $viewModel.criteria.network.response)
        }, content: {
            ConsoleSearchStatusCodeCell(selection: $viewModel.criteria.network.response.statusCode.range)
#if !os(watchOS)
            ConsoleSearchDurationCell(selection: $viewModel.criteria.network.response.duration)
            ConsoleSearchResponseSizeCell(selection: $viewModel.criteria.network.response.responseSize)
#endif
            ConsoleSearchContentTypeCell(selection: $viewModel.criteria.network.response.contentType.contentType)
        })
    }

    var requestSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "arrow.up.circle", title: "Request", filter: $viewModel.criteria.network.request)
        }, content: {
            ConsoleSearchHTTPMethodCell(selection: $viewModel.criteria.network.request.httpMethod)
#if !os(watchOS)
            ConsoleSearchRequestSizeCell(selection: $viewModel.criteria.network.request.requestSize)
#endif
        })
    }

    var networkingSection: some View {
        ConsoleSection(header: {
            ConsoleSearchSectionHeader(icon: "arrowshape.zigzag.right", title: "Advanced", filter: $viewModel.criteria.network.networking)
        }, content: {
            ConsoleSearchTaskTypeCell(selection: $viewModel.criteria.network.networking.taskType)
            ConsoleSearchRequestStateCell(selection: $viewModel.criteria.network.networking.requestState)
            ConsoleSearchResponseSourceCell(selection: $viewModel.criteria.network.networking.source)
            ConsoleSearchToggleCell(title: "Redirect", isOn: $viewModel.criteria.network.networking.isRedirect)
        })
    }
}

#if DEBUG
import CoreData

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Messages", traits: .fixedLayout(width: 280, height: 900)) {
    let store = LoggerStore.mock
    let entities: [NSManagedObject] = try! store.messages()
    let environment = ConsoleEnvironment(store: store)
    let viewModel = environment.filters
    viewModel.entities.send(entities)
    viewModel.mode = .logs

    let content = ConsoleFiltersView()
        .environmentObject(viewModel)
        .environmentObject(environment)
#if os(macOS)
    return content
#else
    return NavigationView {
        content
    }
    .navigationViewStyle(.stack)
#endif
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Network", traits: .fixedLayout(width: 280, height: 900)) {
    let store = LoggerStore.mock
    let entities: [NSManagedObject] = try! store.tasks()
    let environment = ConsoleEnvironment(store: store)
    let viewModel = environment.filters
    viewModel.entities.send(entities)
    viewModel.mode = .network

    let content = ConsoleFiltersView()
        .environmentObject(viewModel)
        .environmentObject(environment)
#if os(macOS)
    return content
#else
    return NavigationView {
        content
    }
    .navigationViewStyle(.stack)
#endif
}
#endif
