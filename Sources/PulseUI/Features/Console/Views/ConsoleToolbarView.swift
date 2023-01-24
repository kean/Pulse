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
            if viewModel.isNetwork {
                ConsoleToolbarTitle(viewModel: viewModel)
            } else {
                switch viewModel.source {
                case .store:
                    ConsoleModePicker(viewModel: viewModel)
                case .entities(_, let entities):
                    ConsoleModeButton(title: viewModel.mode == .tasks ? "Tasks" : "Logs", details: "\(entities.count)", isSelected: false) {}
                }
            }
            Spacer()
            HStack(spacing: 14) {
                ConsoleFiltersView(viewModel: viewModel)
            }.padding(.trailing, -2)
        }
        .buttonStyle(.plain)
    }
}

private struct ConsoleModePicker: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var logsCounter: ManagedObjectsCountObserver
    @ObservedObject var tasksCounter: ManagedObjectsCountObserver

    @State private var mode: ConsoleMode = .all
    @State private var title: String = ""

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.logsCounter = viewModel.list.logCountObserver
        self.tasksCounter = viewModel.list.taskCountObserver
    }

    var body: some View {
        HStack(spacing: 12) {
            ConsoleModeButton(title: "All", isSelected: mode == .all) {
                viewModel.mode = .all
            }
            ConsoleModeButton(title: "Logs", details: "\(logsCounter.count)", isSelected: mode == .logs) {
                viewModel.mode = .logs
            }
            ConsoleModeButton(title: "Tasks", details: "\(tasksCounter.count)", isSelected: mode == .tasks) {
                viewModel.mode = .tasks
            }
        }
        .onReceive(viewModel.list.$mode) { mode = $0 }
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
        viewModel.list.$entities.map { entities in
            "\(entities.count) Requests"
        }
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
                    .foregroundColor(isSelected ? Color.blue : Color.secondary)
                    .font(.subheadline.weight(.medium))
                if let details = details {
                    Text("(\(details))")
                        .foregroundColor(isSelected ? Color.blue.opacity(0.7) : Color.secondary.opacity(0.7))
                        .font(.subheadline)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ConsoleFiltersView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var listViewModel: ConsoleListViewModel
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.listViewModel = viewModel.list
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
    }

    var body: some View {
        if #available(iOS 15, *) {
            sortByMenu.fixedSize()
            groupByMenu.fixedSize()
        }
        Button(action: { searchCriteriaViewModel.isOnlyErrors.toggle() }) {
            Image(systemName: searchCriteriaViewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(searchCriteriaViewModel.isOnlyErrors ? .red : .accentColor)
        }
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
                .foregroundColor(.blue)
        })
    }
}

#endif
