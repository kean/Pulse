// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

@available(iOS 15, macOS 13, *)
struct ConsoleFiltersView: View {
    @EnvironmentObject var environment: ConsoleEnvironment // important: reloads mode
    @EnvironmentObject var viewModel: ConsoleFiltersViewModel

    var body: some View {
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
                Text(environment.mode == .network ? "Network Filters" : "Message Filters")
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

        if environment.mode == .network {
#if PULSE_STANDALONE_APP
            customNetworkFiltersSection
#endif
            domainsSection

#if PULSE_STANDALONE_APP
            responseSection
            networkingSection
#endif
        } else {
#if PULSE_STANDALONE_APP
            customMessageFiltersSection
#endif
            logLevelsSection
            labelsSection
        }

#if os(iOS) || os(macOS)
        timePeriodSection
#endif
    }

    private var buttonReset: some View {
        Button(role: .destructive, action: viewModel.resetAll) { Text("Reset") }
            .disabled(viewModel.isDefaultFilters(for: environment.mode))
    }
}

// MARK: - ConsoleFiltersView (Sections)

@available(iOS 15, macOS 13, *)
extension ConsoleFiltersView {
    var sessionsSection: some View {
        ConsoleSection(isDividerHidden: true, header: {
            ConsoleSectionHeader(icon: "list.clipboard", title: "Sessions", filter: $viewModel.criteria.shared.sessions, default: viewModel.defaultCriteria.shared.sessions)
        }, content: {
            ConsoleSessionsPickerView(selection: $viewModel.criteria.shared.sessions.selection)
        })
    }

#if os(iOS) || os(macOS)
    var timePeriodSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "calendar", title: "Time Period", filter: $viewModel.criteria.shared.dates)
        }, content: {
            ConsoleSearchTimePeriodCell(selection: $viewModel.criteria.shared.dates)
        })
    }
#endif

    var logLevelsSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "flag", title: "Levels", filter: $viewModel.criteria.messages.logLevels)
        }, content: {
            ConsoleSearchLogLevelsCell(selection: $viewModel.criteria.messages.logLevels.levels)
        })
    }

    var labelsSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "tag", title: "Labels", filter: $viewModel.criteria.messages.labels)
        }, content: {
            ConsoleLabelsSelectionView(viewModel: viewModel)
        })
    }

    var domainsSection: some View {
        ConsoleSection(header: {
            ConsoleSectionHeader(icon: "server.rack", title: "Hosts", filter: $viewModel.criteria.network.host)
        }, content: {
            ConsoleDomainsSelectionView(viewModel: viewModel)
        })
    }
}

#if DEBUG
import CoreData

@available(iOS 15, macOS 13, *)
struct ConsoleFiltersView_Previews: PreviewProvider {
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
        .injecting(.init(store: .mock))
#endif
    }
}

@available(iOS 15, macOS 13, *)
private func makePreview(isOnlyNetwork: Bool) -> some View {
    let store = LoggerStore.mock
    let entities: [NSManagedObject] = try! isOnlyNetwork ? store.allTasks() : store.allMessages()
    let viewModel = ConsoleFiltersViewModel(options: .init())
    viewModel.entities.send(entities)
    viewModel.mode = isOnlyNetwork ? .network : .all
    return ConsoleFiltersView()
        .injecting(ConsoleEnvironment(store: store))
        .environmentObject(viewModel)
}
#endif
