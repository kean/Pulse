// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

struct ConsoleSearchCriteriaView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    var body: some View {
        contents
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
    }

    var contents: some View {
#if os(iOS) || os(watchOS) || os(tvOS)
        Form {
            form
        }
#if os(iOS)
        .navigationBarItems(leading: buttonReset)
#endif
#else
        ScrollView {
            form.frame(width: 310)
        }
#endif
    }

    @ViewBuilder
    private var form: some View {
#if os(tvOS) || os(watchOS)
        buttonReset
#elseif os(macOS)
        HStack {
            Text(viewModel.mode == .tasks ? "Network Filters" : "Message Filters")
                .font(.headline)
            Spacer()
            buttonReset
        }
        .padding(12)
#endif

        timePeriodSection

        if viewModel.mode == .tasks {
#if os(iOS) || os(macOS)
            if #available(iOS 15, *) {
                customNetworkFiltersSection
            }
#endif
            responseSection
            domainsSection
            networkingSection
        } else {
#if os(iOS) || os(macOS)
            if #available(iOS 15, *) {
                customMessageFiltersSection
            }
#endif
            logLevelsSection
            labelsSection
        }
    }

    private var buttonReset: some View {
        Button.destructive(action: viewModel.resetAll) { Text("Reset") }
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

// MARK: - ConsoleSearchView (Shared)

extension ConsoleSearchCriteriaView {
    var timePeriodSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "calendar", title: "Time Period", filter: $viewModel.criteria.shared.dates, default: viewModel.defaultCriteria.shared.dates)
        }, content: {
            ConsoleSearchTimePeriodCell(selection: $viewModel.criteria.shared.dates)
        })
    }
}

// MARK: - ConsoleSearchView (Message)

extension ConsoleSearchCriteriaView {
#if os(iOS) || os(macOS)
    @available(iOS 15, *)
    var customMessageFiltersSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.messages.custom)
        }, content: {
            ConsoleSearchCustomMessageFiltersSection(selection: $viewModel.criteria.messages.custom)
        })
    }
#endif

    var logLevelsSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "flag", title: "Levels", filter: $viewModel.criteria.messages.logLevels)
        }, content: {
            ConsoleSearchLogLevelsCell(viewModel: viewModel)
        })
    }

    var labelsSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "tag", title: "Labels", filter: $viewModel.criteria.messages.labels)
        }, content: {
            ConsoleSearchListSelectionView(
                title: "Labels",
                items: viewModel.labels,
                selection: $viewModel.selectedLabels,
                description: { $0 },
                label: {
                    ConsoleSearchListCell(title: $0, details: "\(viewModel.labelsCountedSet.count(for: $0))")
                }
            )
        })
    }
}

// MARK: - ConsoleSearchView (Network)

extension ConsoleSearchCriteriaView {
#if os(iOS) || os(macOS)
    @available(iOS 15, *)
    var customNetworkFiltersSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.network.custom)
        }, content: {
            ConsoleSearchCustomNetworkFiltersSection(selection: $viewModel.criteria.network.custom)
        })
    }
#endif

    var responseSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "arrow.down.circle", title:  "Response", filter: $viewModel.criteria.network.response)
        }, content: {
#if os(iOS) || os(macOS)
            ConsoleSearchStatusCodeCell(selection: $viewModel.criteria.network.response.statusCode.range)
            ConsoleSearchDurationCell(selection: $viewModel.criteria.network.response.duration)
            ConsoleSearchResponseSizeCell(selection: $viewModel.criteria.network.response.responseSize)
#endif
            ConsoleSearchContentTypeCell(selection: $viewModel.criteria.network.response.contentType.contentType)
        })
    }

    var domainsSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "server.rack", title: "Hosts", filter: $viewModel.criteria.network.host)
        }, content: {
            ConsoleSearchListSelectionView(
                title: "Hosts",
                items: viewModel.domains,
                selection: $viewModel.selectedHost,
                description: { $0 },
                label: {
                    ConsoleSearchListCell(title: $0, details: "\(viewModel.domainsCountedSet.count(for: $0))")
                }
            )
        })
    }

    var networkingSection: some View {
        ConsoleSearchSection(header: {
            ConsoleSearchSectionHeader(icon: "arrowshape.zigzag.right", title: "Networking", filter: $viewModel.criteria.network.networking)
        }, content: {
            ConsoleSearchTaskTypeCell(selection: $viewModel.criteria.network.networking.taskType)
            ConsoleSearchResponseSourceCell(selection: $viewModel.criteria.network.networking.source)
            ConsoleSearchToggleCell(title: "Redirect", isOn: $viewModel.criteria.network.networking.isRedirect)
        })
    }
}

#if DEBUG
import CoreData

struct ConsoleSearchCriteriaView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        Group {
            makePreview(isOnlyNetwork: false)
                .previewLayout(.fixed(width: 320, height: 900))
                .previewDisplayName("Messages")

            makePreview(isOnlyNetwork: true)
                .previewLayout(.fixed(width: 320, height: 900))
                .previewDisplayName("Network")
        }
#else
        Group {
            NavigationView {
                makePreview(isOnlyNetwork: false)
            }
            .navigationViewStyle(.stack)
            .previewDisplayName("Messages")

            NavigationView {
                makePreview(isOnlyNetwork: true)
            }
            .navigationViewStyle(.stack)
            .previewDisplayName("Network")
        }
#endif
    }
}

private func makePreview(isOnlyNetwork: Bool) -> some View {
    let store = LoggerStore.mock
    let entities: [NSManagedObject] = try! isOnlyNetwork ? store.allTasks() : store.allMessages()
    let viewModel = ConsoleSearchCriteriaViewModel(store: store, source: .store)
    viewModel.bind(CurrentValueSubject(entities))
    viewModel.mode = isOnlyNetwork ? .tasks : .all
    return ConsoleSearchCriteriaView(viewModel: viewModel)
}
#endif
