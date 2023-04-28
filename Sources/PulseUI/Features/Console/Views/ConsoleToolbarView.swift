// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)
struct ConsoleToolbarView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits {
                horizontal
                vertical
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else {
            horizontal
        }
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
#elseif os(macOS)
struct ConsoleToolbarView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    var body: some View {
        HStack {
            if filters.options.focus != nil {
                makeFocusedView()
            } else {
                ConsoleModePicker(environment: environment)
            }
            Spacer()
            ConsoleListOptionsView()
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .pickerStyle(.inline)
        }
        .padding(.horizontal, 10)
        .frame(height: 27, alignment: .center)
    }

    @ViewBuilder
    private func makeFocusedView() -> some View {
        Text("Focused Logs")
            .foregroundColor(.secondary)
            .font(.subheadline.weight(.medium))

        Button(action: { filters.options.focus = nil }) {
            Image(systemName: "xmark")
        }
        .foregroundColor(.secondary)
        .buttonStyle(.plain)
        .help("Unfocus")
    }
}
#endif

struct ConsoleModePicker: View {
    @ObservedObject private var environment: ConsoleEnvironment

    @ObservedObject private var logsCounter: ManagedObjectsCountObserver
    @ObservedObject private var tasksCounter: ManagedObjectsCountObserver

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.logsCounter = environment.logCountObserver
        self.tasksCounter = environment.taskCountObserver
    }

#if os(macOS)
    let spacing: CGFloat = 4
#else
    let spacing: CGFloat = 12
#endif

    var body: some View {
        HStack(spacing: spacing) {
            ConsoleModeButton(title: "All", isSelected: environment.mode == .all) {
                environment.mode = .all
            }
            ConsoleModeButton(title: "Logs", details: CountFormatter.string(from: logsCounter.count), isSelected: environment.mode == .logs) {
                environment.mode = .logs
            }
            ConsoleModeButton(title: "Network", details: CountFormatter.string(from: tasksCounter.count), isSelected: environment.mode == .network) {
                environment.mode = .network
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

#if os(macOS)
    var body: some View {
        InlineTabBarItem(title: title, details: details, isSelected: isSelected, action: action)
    }
#else
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .foregroundColor(isSelected ? Color.blue : Color.secondary)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                if let details = details {
                    Text("(\(details))")
                        .foregroundColor(isSelected ? Color.blue.opacity(0.7) : Color.secondary.opacity(0.7))
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
#endif
}

struct ConsoleListOptionsView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment // important: reloads mode
    @EnvironmentObject private var listViewModel: ConsoleListViewModel
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    var body: some View {
        if #available(iOS 15, *) {
            contents.dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } else {
            contents
        }
    }

    @ViewBuilder
    private var contents: some View {
        if #available(iOS 15, *) {
#if os(iOS)
            sortByMenu.fixedSize()
#endif
            groupByMenu.fixedSize()
        }

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
                .foregroundColor(filters.options.isOnlyErrors ? .red : .blue)
        }
        .padding(.leading, 1)
#endif
    }

    @ViewBuilder
    private var sortByMenu: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Sort By", selection: $listViewModel.options.taskSortBy) {
                    ForEach(ConsoleListOptions.TaskSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Picker("Sort By", selection: $listViewModel.options.messageSortBy) {
                    ForEach(ConsoleListOptions.MessageSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
            Picker("Ordering", selection: $listViewModel.options.order) {
                Text("Descending").tag(ConsoleListOptions.Ordering.descending)
                Text("Ascending").tag(ConsoleListOptions.Ordering.ascending)
            }
        }, label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundColor(.blue)
        })
    }

    @ViewBuilder
    private var groupByMenu: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Group By", selection: $listViewModel.options.taskGroupBy) {
                    Group {
                        Text("Ungrouped").tag(ConsoleListOptions.TaskGroupBy.noGrouping)
                        Divider()
                        Text("URL").tag(ConsoleListOptions.TaskGroupBy.url)
                        Text("Host").tag(ConsoleListOptions.TaskGroupBy.host)
                        Text("Method").tag(ConsoleListOptions.TaskGroupBy.method)
                    }
                    Group {
                        Divider()
                        Text("Content Type").tag(ConsoleListOptions.TaskGroupBy.responseContentType)
                        Text("Status Code").tag(ConsoleListOptions.TaskGroupBy.statusCode)
                        Text("Error Code").tag(ConsoleListOptions.TaskGroupBy.errorCode)
                        Divider()
                        Text("Task State").tag(ConsoleListOptions.TaskGroupBy.requestState)
                        Text("Task Type").tag(ConsoleListOptions.TaskGroupBy.taskType)
                        Divider()
                        Text("Session").tag(ConsoleListOptions.TaskGroupBy.session)
                    }
                }
            } else {
                Picker("Group By", selection: $listViewModel.options.messageGroupBy) {
                    Text("Ungrouped").tag(ConsoleListOptions.MessageGroupBy.noGrouping)
                    Divider()
                    ForEach(ConsoleListOptions.MessageGroupBy.allCases.filter { $0 != .noGrouping }, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
        }, label: {
            Image(systemName: "rectangle.3.group")
                .font(.body)
                .foregroundColor(.blue)
        })
    }
}

#endif
