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
        VStack(spacing: 0) {
            ScrollView {
                form
            }
            HStack {
                Text(viewModel.mode == .network ? "Network Filters" : "Message Filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                buttonReset
            }
            .padding(.horizontal, 10)
            .frame(height: 34, alignment: .center)
        }
#endif
    }

    @ViewBuilder
    private var form: some View {
#if os(tvOS) || os(watchOS)
        buttonReset
#endif

        sessionsSection

        if viewModel.mode == .network {
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

        timePeriodSection
    }

    private var buttonReset: some View {
        Button.destructive(action: viewModel.resetAll) { Text("Reset") }
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

// MARK: - ConsoleSearchView (Shared)

extension ConsoleSearchCriteriaView {
    var sessionsSection: some View {
        ConsoleSection(isDividerHidden: true, header: {
            ConsoleSectionHeader(icon: "list.clipboard", title: "Sessions", filter: $viewModel.criteria.shared.sessions, default: viewModel.defaultCriteria.shared.sessions)
        }, content: {
            ConsoleSessionsPickerView(selection: $viewModel.criteria.shared.sessions.selection)
        })
    }

    var timePeriodSection: some View {
        ConsoleSection(isDividerHidden: true, header: {
            ConsoleSectionHeader(icon: "calendar", title: "Time Period", filter: $viewModel.criteria.shared.dates)
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
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.messages.custom)
        }, content: {
            ConsoleSearchCustomMessageFiltersSection(selection: $viewModel.criteria.messages.custom)
        })
    }
#endif

    var logLevelsSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "flag", title: "Levels", filter: $viewModel.criteria.messages.logLevels)
        }, content: {
            ConsoleSearchLogLevelsCell(viewModel: viewModel)
        })
    }

    var labelsSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "tag", title: "Labels", filter: $viewModel.criteria.messages.labels)
        }, content: {
            ConsoleSearchListSelectionView(
                title: "Labels",
                items: viewModel.labels,
                id: \.self,
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
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.network.custom)
        }, content: {
            ConsoleSearchCustomNetworkFiltersSection(selection: $viewModel.criteria.network.custom)
        })
    }
#endif

    var responseSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "arrow.down.circle", title:  "Response", filter: $viewModel.criteria.network.response)
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
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "server.rack", title: "Hosts", filter: $viewModel.criteria.network.host)
        }, content: {
            ConsoleSearchListSelectionView(
                title: "Hosts",
                items: viewModel.domains,
                id: \.self,
                selection: $viewModel.selectedHost,
                description: { $0 },
                label: {
                    ConsoleSearchListCell(title: $0, details: "\(viewModel.domainsCountedSet.count(for: $0))")
                }
            )
        })
    }

    var networkingSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "arrowshape.zigzag.right", title: "Networking", filter: $viewModel.criteria.network.networking)
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
                .previewLayout(.fixed(width: 280, height: 900))
                .previewDisplayName("Messages")

            makePreview(isOnlyNetwork: true)
                .previewLayout(.fixed(width: 280, height: 900))
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
        .injectingEnvironment(.init(store: .mock))
#endif
    }
}

private func makePreview(isOnlyNetwork: Bool) -> some View {
    let store = LoggerStore.mock
    let entities: [NSManagedObject] = try! isOnlyNetwork ? store.allTasks() : store.allMessages()
    let viewModel = ConsoleSearchCriteriaViewModel(options: .init(), index: .init(store: store))
    viewModel.bind(CurrentValueSubject(entities))
    viewModel.mode = isOnlyNetwork ? .network : .all
    return ConsoleSearchCriteriaView(viewModel: viewModel)
}
#endif
