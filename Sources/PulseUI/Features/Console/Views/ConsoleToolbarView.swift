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
            ConsoleToolbarTitle(viewModel: viewModel)
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

private struct ConsoleToolbarTitle: View {
    let viewModel: ConsoleViewModel

    @State private var title: String = ""

    var body: some View {
        Text(title)
            .foregroundColor(.secondary)
            .font(.subheadline.weight(.medium))
            .onReceive(titlePublisher) { title = $0 }
    }

    #warning("remove")
    private var titlePublisher: some Publisher<String, Never> {
        viewModel.list.$entities.combineLatest(viewModel.list.$mode)
            .map { entities, isOnlyNetwork in
                "\(entities.count) \(viewModel.list.mode == .tasks ? "Requests" : "Messages")"
            }
    }
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
