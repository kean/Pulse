// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)

struct ConsoleToolbarView: View {
    let viewModel: ConsoleViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ConsoleModePicker(viewModel: viewModel)
            Spacer()
            HStack(spacing: 14) {
                ConsoleFiltersView(
                    isNetworkModeEnabled: viewModel.isNetworkModeEnabled,
                    viewModel: viewModel.searchCriteriaViewModel,
                    router: viewModel.router
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ConsoleModePicker: View {
    let viewModel: ConsoleViewModel

    @State private var mode: ConsoleMode = .all
    @State private var title: String = ""

    var body: some View {
        HStack(spacing: 12) {
            ConsoleModeButton(title: "All", isSelected: mode == .all) {
                viewModel.mode = .all
            }
            ConsoleModeButton(title: "Logs", isSelected: mode == .logs) {
                viewModel.mode = .logs
            }
            ConsoleModeButton(title: "Tasks", isSelected: mode == .tasks) {
                viewModel.mode = .tasks
            }
        }
        .onReceive(viewModel.list.$mode) { mode = $0 }
    }

    #warning("remove")
    private var titlePublisher: some Publisher<String, Never> {
        viewModel.list.$entities.combineLatest(viewModel.list.$mode)
            .map { entities, isOnlyNetwork in
                "\(entities.count) \(viewModel.list.mode == .tasks ? "Requests" : "Messages")"
            }
    }
}

private struct ConsoleModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(isSelected ? Color.blue : Color.secondary)
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.plain)
    }

#warning("add counters")
    //  + Text(" (4K)").foregroundColor(Color.separator)
}

struct ConsoleFiltersView: View {
    let isNetworkModeEnabled: Bool
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @ObservedObject var router: ConsoleRouter

    var body: some View {
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
        }
        Button(action: { router.isShowingFilters = true }) {
            Image(systemName: viewModel.isCriteriaDefault ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }
    }
}

#endif
