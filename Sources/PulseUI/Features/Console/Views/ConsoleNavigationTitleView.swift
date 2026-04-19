// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS) || os(visionOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleNavigationTitleView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var listViewModel: ConsoleListViewModel
    @EnvironmentObject private var searchViewModel: ConsoleSearchViewModel

    var body: some View {
        Menu {
            modeButton(.all, title: "All")
            modeButton(.logs, title: "Logs")
            modeButton(.network, title: "Network")
        } label: {
            headerView
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            VStack(alignment: .center, spacing: 0) {
                Text(modeTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.down.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary, Color(.tertiarySystemFill))
                .offset(y: -1)
        }
    }

    private func modeButton(_ mode: ConsoleMode, title: String) -> some View {
        Button {
            environment.mode = mode
        } label: {
            if environment.mode == mode {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var modeTitle: String {
        switch environment.mode {
        case .all: return "Console"
        case .logs: return "Logs"
        case .network: return "Network"
        }
    }

    private var subtitle: String {
        let total = environment.mode.formattedCount(listViewModel.entities.count)
        if searchViewModel.isSearching, searchViewModel.searchBar.text.isEmpty == false {
            return "\(searchViewModel.results.count)\(searchViewModel.hasMore ? "+" : "") / \(total)"
        }
        return total
    }
}

#endif
