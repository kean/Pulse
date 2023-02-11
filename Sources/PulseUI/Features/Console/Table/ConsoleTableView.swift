// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct ConsoleTableView: View {
    var viewModel: ConsoleTableViewModel
    @Binding var selection: NSManagedObjectID?

    var body: some View {
        _ConsoleTableView(viewModel: viewModel, selection: $selection)
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
    }
}

private struct _ConsoleTableView: View {
    @ObservedObject var viewModel: ConsoleTableViewModel
    @Binding var selection: NSManagedObjectID?

    var body: some View {
        switch viewModel.mode {
        case .all, .logs:
            ConsoleMessageTableView(viewModel: viewModel, selection: $selection)
        case .tasks:
            ConsoleTaskTableView(viewModel: viewModel, selection: $selection)
        }
    }
}

private struct ConsoleMessageTableView: View {
    @ObservedObject var viewModel: ConsoleTableViewModel
    @Binding var selection: NSManagedObjectID?
    @State private var sortOrder: [SortDescriptor<LoggerMessageEntity>] = []

    var body: some View {
        Table((viewModel.entities as? [LoggerMessageEntity]) ?? [], selection: $selection, sortOrder: $sortOrder) {
            TableColumn("", value: \.level) {
                if let task = $0.task {
                    Image(systemName: task.state.iconSystemName)
                        .foregroundColor(task.state.tintColor)
                }
            }.width(15)

            TableColumn("Message", value: \.text) {
                Text($0.text)
                    .foregroundColor(textColor(for: $0))
            }.width(min: 40, ideal: 600)

            TableColumn("Level", value: \.level) {
                Text($0.logLevel.name)
                    .foregroundColor(.secondary)
            }.width(min: 54, ideal: 54, max: 54)

            TableColumn("Label", value: \.label) {
                Text($0.label)
                    .foregroundColor(.secondary)
            }.width(min: 54, ideal: 68)

            TableColumn("Date & Time", value: \.createdAt) {
                Text(dateAndTimeFormatter.string(from: $0.createdAt))
                    .foregroundColor(.secondary)
            }.width(min: 87, ideal: 162, max: 162)

            TableColumn("File", value: \.file) {
                Text($0.file)
                    .foregroundColor(.secondary)
            }.width(ideal: 80)
        }
        .tableStyle(.inset)
        .onChange(of: sortOrder) {
            viewModel.sort(using: $0.map(NSSortDescriptor.init))
        }
    }

    private func textColor(for message: LoggerMessageEntity) -> Color {
        if selection == message.objectID {
            return Color.primary
        }
        return Color.textColor(for: message.logLevel)
    }
}

private struct ConsoleTaskTableView: View {
    @ObservedObject var viewModel: ConsoleTableViewModel
    @Binding var selection: NSManagedObjectID?
    @State private var sortOrder: [SortDescriptor<NetworkTaskEntity>] = []

    var body: some View {
        Table(((viewModel.entities as? [NetworkTaskEntity]) ?? []), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("", value: \.requestState) {
                Image(systemName: $0.state.iconSystemName)
                    .foregroundColor($0.state.tintColor)
            }.width(15)

            TableColumn("Status Code", value: \.statusCode) {
                if $0.statusCode > 0 {
                    Text("\($0.statusCode)").foregroundColor(textColor(for: $0))
                } else {
                    Text("–").foregroundColor(textColor(for: $0))
                }
            }.width(30)

            TableColumn("Method", value: \.httpMethod) {
                Text($0.httpMethod ?? "–")
                    .foregroundColor(textColor(for: $0))
            }.width(min: 40, ideal: 46, max: 60)

            TableColumn("URL", value: \.url) {
                Text($0.url ?? "–")
                    .foregroundColor(textColor(for: $0))
            }.width(min: 40, ideal: 460)

            TableColumn("Date & Time", value: \.createdAt) {
                Text(dateAndTimeFormatter.string(from: $0.createdAt))
                    .foregroundColor(.secondary)
            }.width(min: 87, ideal: 162, max: 162)

            TableColumn("Duration", value: \.duration) {
                Text(DurationFormatter.string(from: $0.duration, isPrecise: false))
                    .foregroundColor(.secondary)
            }.width(min: 50, ideal: 64, max: 80)

            TableColumn("Request Size", value: \.requestBodySize) {
                Text(ByteCountFormatter.string(fromByteCount: $0.requestBodySize))
                    .foregroundColor(.secondary)
            }.width(min: 50, ideal: 64, max: 80)

            TableColumn("Response Size", value: \.responseBodySize) {
                Text(ByteCountFormatter.string(fromByteCount: $0.responseBodySize))
                    .foregroundColor(.secondary)
            }.width(min: 50, ideal: 64, max: 80)
        }
        .tableStyle(.inset)
        .onChange(of: sortOrder) {
            viewModel.sort(using: $0.map(NSSortDescriptor.init))
        }
    }

    private func textColor(for task: NetworkTaskEntity) -> Color {
        if selection == task.objectID {
            return Color.primary
        }
        return task.state == .failure ? Color.red : Color.primary
    }
}

private let dateAndTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()

#if DEBUG
struct ConsoleTableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let viewModel = ConsoleViewModel(store: .mock)
            ConsoleTableView(viewModel: viewModel.tableViewModel, selection: .constant(nil))
                .previewLayout(.fixed(width: 1200, height: 800))
                .previewDisplayName("Logs")
        }
        Group {
            let viewModel = ConsoleViewModel(store: .mock)
            let _ = viewModel.mode = .tasks
            ConsoleTableView(viewModel: viewModel.tableViewModel, selection: .constant(nil))
                .previewLayout(.fixed(width: 1200, height: 800))
                .previewDisplayName("Tasks")
        }
    }
}
#endif
#endif
