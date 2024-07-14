// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleToolbarView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
#if os(macOS)
        horizontal
            .padding(.horizontal)
            .frame(height: 34, alignment: .center)
#else
        if #available(iOS 16.0, *) {
            ViewThatFits {
                horizontal
                vertical
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else {
            horizontal
        }
#endif
    }

    private var horizontal: some View {
        HStack(alignment: .bottom, spacing: 0) {
            contents(isVertical: false)
        }
        .buttonStyle(.plain)
    }

    // Fallback for larger dynamic font sizes.
    private var vertical: some View {
        VStack(alignment: .leading, spacing: 16) {
            contents(isVertical: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contents(isVertical: Bool) -> some View {
        switch environment.initialMode {
        case .all:
            ConsoleModePicker(environment: environment)
        case .logs, .network:
            ConsoleToolbarTitle()
        }
        if !isVertical {
            Spacer()
        }
        HStack(spacing: 14) {
            ConsoleListOptionsView()
        }.padding(.trailing, isVertical ? 0 : -2)
    }
}

struct ConsoleModePicker: View {
    @ObservedObject private var environment: ConsoleEnvironment

    @ObservedObject private var logsCounter: ManagedObjectsCountObserver
    @ObservedObject private var tasksCounter: ManagedObjectsCountObserver

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.logsCounter = environment.logCountObserver
        self.tasksCounter = environment.taskCountObserver
    }

    var body: some View {
        HStack(spacing: 12) {
            ConsoleModeButton(title: "Network", details: CountFormatter.string(from: tasksCounter.count), isSelected: environment.mode == .network) {
                environment.mode = .network
            }
            ConsoleModeButton(title: "Logs", details: CountFormatter.string(from: logsCounter.count), isSelected: environment.mode == .logs) {
                environment.mode = .logs
            }
            ConsoleModeButton(title: "All", details: CountFormatter.string(from: logsCounter.count + tasksCounter.count), isSelected: environment.mode == .all) {
                environment.mode = .all
            }
        }
    }
}

private struct ConsoleToolbarTitle: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var listViewModel: ConsoleListViewModel

    var body: some View {
        Text(title)
            .foregroundColor(.secondary)
            .font(.subheadline.weight(.medium))
    }

    private var title: String {
        let kind = environment.initialMode == .network ? "Requests" : "Logs"
        return "\(listViewModel.entities.count) \(kind)"
    }
}

private struct ConsoleModeButton: View {
    let title: String
    var details: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                if let details = details {
                    Text("(\(details))")
                        .foregroundColor(isSelected ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.7))
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 15, visionOS 1.0, *)
struct ConsoleListOptionsView: View {
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    var body: some View {
#if os(macOS)
        Button(action: { filters.options.isOnlyErrors.toggle() }) {
            Image(systemName: filters.options.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(filters.options.isOnlyErrors ? .red : .primary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .help("Toggle Show Only Errors (⇧⌘E)")
#else
        Button(action: { filters.options.isOnlyErrors.toggle() }) {
            Text(Image(systemName: filters.options.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon"))
                .font(.body)
                .foregroundColor(.accentColor)
        }
        .cornerRadius(4)
        .padding(.leading, 1)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
#endif
    }
}

#endif
