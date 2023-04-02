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
    let viewModel: ConsoleViewModel

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
        if viewModel.isNetwork {
            ConsoleToolbarTitle(viewModel: viewModel)
        } else {
            if viewModel.context.focus != nil {
                ConsoleModeButton(title: viewModel.mode == .tasks ? "Focused Tasks" : "Focused Logs", isSelected: false) {}
            } else {
                ConsoleModePicker(viewModel: viewModel)
            }
        }
        if !isVertical {
            Spacer()
        }
        HStack(spacing: 14) {
            ConsoleFiltersView(viewModel: viewModel)
        }.padding(.trailing, isVertical ? 0 : -2)
    }
}
#elseif os(macOS)
struct ConsoleToolbarView: View {
    let viewModel: ConsoleViewModel

    @ObservedObject private var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
    }

    var body: some View {
        HStack {
            if searchCriteriaViewModel.focus != nil {
                makeFocusedView()
            } else {
                ConsoleModePicker(viewModel: viewModel)
            }
            Spacer()
            ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.searchCriteriaViewModel)
        }
        .padding(.horizontal, 10)
        .frame(height: 34, alignment: .center)
    }

    @ViewBuilder
    private func makeFocusedView() -> some View {
        Text("Focused Logs")
            .foregroundColor(.secondary)
            .font(.subheadline.weight(.medium))

        Button(action: { searchCriteriaViewModel.focus = nil }) {
            Image(systemName: "xmark")
        }
        .foregroundColor(.secondary)
        .buttonStyle(.plain)
        .help("Unfocus")
    }
}
#endif

struct ConsoleModePicker: View {
    let viewModel: ConsoleViewModel

    @ObservedObject private var logsCounter: ManagedObjectsCountObserver
    @ObservedObject private var tasksCounter: ManagedObjectsCountObserver

    @State private var mode: ConsoleMode = .all

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.logsCounter = viewModel.logCountObserver
        self.tasksCounter = viewModel.taskCountObserver
    }

#if os(macOS)
    let spacing: CGFloat = 4
#else
    let spacing: CGFloat = 12
#endif

    var body: some View {
        HStack(spacing: spacing) {
            ConsoleModeButton(title: "All", isSelected: mode == .all) { mode = .all }
            ConsoleModeButton(title: "Logs", details: "\(logsCounter.count)", isSelected: mode == .logs) { mode = .logs }
            ConsoleModeButton(title: "Tasks", details: "\(tasksCounter.count)", isSelected: mode == .tasks) { mode = .tasks }
        }
        .onChange(of: mode) {
            viewModel.mode = $0
        }
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

    private var titlePublisher: some Publisher<String, Never> {
        viewModel.listViewModel.$entities.map { entities in
            "\(entities.count) Requests"
        }
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

struct ConsoleFiltersView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var listViewModel: ConsoleListViewModel
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.listViewModel = viewModel.listViewModel
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
    }

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
            sortByMenu.fixedSize()
            groupByMenu.fixedSize()
        }
        Button(action: { searchCriteriaViewModel.isOnlyErrors.toggle() }) {
            Text(Image(systemName: searchCriteriaViewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon"))
                .font(.body)
                .foregroundColor(searchCriteriaViewModel.isOnlyErrors ? .red : .blue)
        }
        .padding(.leading, 1)
    }

    @ViewBuilder
    private var sortByMenu: some View {
        Menu(content: {
            if viewModel.mode == .tasks {
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
            if viewModel.mode == .tasks {
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
