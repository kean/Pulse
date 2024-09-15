// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 16, visionOS 1, *)
struct ConsoleToolbarView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        ViewThatFits {
            horizontal
            vertical
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var horizontal: some View {
        HStack(alignment: .center, spacing: 0) {
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
        HStack(spacing: 7) {
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

package struct ConsoleModeButton: View {
    package let title: String
    package var details: String?
    package let isSelected: Bool
    package let action: () -> Void

    package init(title: String, details: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.details = details
        self.isSelected = isSelected
        self.action = action
    }

    package var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .foregroundColor(isSelected ? Color.white : Color.secondary)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                if let details = details {
                    Text("\(details)")
                        .foregroundColor(isSelected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.7))
                        .font(.footnote)
                        .monospacedDigit()
                        .lineLimit(1)
                        .allowsTightening(true)
                }
            }
            .padding(EdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 8))
            .background(isSelected ? Color.accentColor : Color(.secondarySystemFill).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 16, visionOS 1, *)
struct ConsoleListOptionsView: View {
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    var body: some View {
        Button(action: { filters.options.isOnlyErrors.toggle() }) {
            Text(Image(systemName: filters.options.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon"))
                .font(.body)
                .foregroundColor(filters.options.isOnlyErrors ? .white : .secondary)
        }
        .cornerRadius(4)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(7)
        .background(filters.options.isOnlyErrors ? .red : Color(.secondarySystemFill).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#endif
