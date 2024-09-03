// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

@available(iOS 15, visionOS 1.0, *)
struct ConsoleFiltersView: View {
    @EnvironmentObject var environment: ConsoleEnvironment // important: reloads mode
    @EnvironmentObject var viewModel: ConsoleFiltersViewModel

    var body: some View {
        Form {
            form
        }
#if os(iOS) || os(visionOS)
        .navigationBarItems(leading: buttonReset)
#endif
    }

    @ViewBuilder
    private var form: some View {
#if os(tvOS) || os(watchOS)
        buttonReset
#endif

        sessionsSection

        if environment.mode == .network {
            domainsSection
        } else {
            logLevelsSection
            labelsSection
        }

#if os(iOS) || os(visionOS)
        timePeriodSection
#endif
    }

    private var buttonReset: some View {
        Button(role: .destructive, action: viewModel.resetAll) { Text("Reset") }
            .disabled(viewModel.isDefaultFilters(for: environment.mode))
    }
}

// MARK: - ConsoleFiltersView (Sections)

@available(iOS 15, visionOS 1.0, *)
extension ConsoleFiltersView {
    var sessionsSection: some View {
        ConsoleSection(isDividerHidden: true, header: {
            ConsoleSectionHeader(icon: "list.clipboard", title: "Sessions", filter: $viewModel.criteria.shared.sessions, default: viewModel.defaultCriteria.shared.sessions)
        }, content: {
            ConsoleSessionsPickerView(selection: $viewModel.criteria.shared.sessions.selection)
        })
    }

#if os(iOS) || os(visionOS)
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

@available(iOS 15, visionOS 1.0, *)
struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
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
    }
}

@available(iOS 15, macOS 13, visionOS 1.0, *)
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

#endif
