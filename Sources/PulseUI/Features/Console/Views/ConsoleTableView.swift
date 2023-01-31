// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct ConsoleTableView: View {
    @ObservedObject var viewModel: ConsoleListViewModel
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
    @ObservedObject var viewModel: ConsoleListViewModel
    @Binding var selection: NSManagedObjectID?
    @State private var sortOrder: [SortDescriptor<LoggerMessageEntity>] = []

    var body: some View {
        Table((viewModel.entities as? [LoggerMessageEntity]) ?? [], selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date & Time", value: \.createdAt) {
                Text(dateAndTimeFormatter.string(from: $0.createdAt))
            }.width(min: 87, ideal: 162, max: 162)
            TableColumn("Level", value: \.level) {
                Text($0.logLevel.name)
            }.width(min: 54, ideal: 54, max: 54)
            TableColumn("Label", value: \.label) {
                Text($0.label)
            }.width(min: 54, ideal: 68)
            TableColumn("Message", value: \.text)
                .width(min: 40, ideal: 600)
            TableColumn("File", value: \.file)
                .width(ideal: 80)
            TableColumn("Function", value: \.function)
                .width(ideal: 100)
        }
        .tableStyle(.inset)
        .onChange(of: sortOrder) {
            viewModel.sortDescriptors = $0.map(NSSortDescriptor.init)
        }
    }
}

private struct ConsoleTaskTableView: View {
    @ObservedObject var viewModel: ConsoleListViewModel
    @Binding var selection: NSManagedObjectID?
    @State private var sortOrder: [SortDescriptor<NetworkTaskEntity>] = []

    var body: some View {
        Table(((viewModel.entities as? [NetworkTaskEntity]) ?? []), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("", value: \.requestState) {
                Image(systemName: $0.state.iconSystemName)
                    .foregroundColor($0.state.tintColor)
            }.width(16)
            TableColumn("Date & Time", value: \.createdAt) {
                Text(dateAndTimeFormatter.string(from: $0.createdAt))
            }.width(min: 87, ideal: 162, max: 162)
            TableColumn("Status Code", value: \.statusCode) {
                if $0.statusCode > 0 {
                    Text("\($0.statusCode)")
                } else {
                    Text("–")
                }
            }.width(30)
            TableColumn("Method", value: \.httpMethod) {
                Text($0.httpMethod ?? "–")
            }.width(min: 40, ideal: 50, max: 60)
            TableColumn("URL", value: \.url) {
                Text($0.url ?? "–")
            }.width(min: 40, ideal: 520)
            TableColumn("Duration", value: \.duration) {
                Text(DurationFormatter.string(from: $0.duration, isPrecise: false))
            }.width(min: 54, ideal: 64, max: 140)
            TableColumn("Request Size", value: \.requestBodySize) {
                Text(ByteCountFormatter.string(fromByteCount: $0.requestBodySize))
            }.width(min: 54, ideal: 64, max: 140)
            TableColumn("Response Size", value: \.responseBodySize) {
                Text(ByteCountFormatter.string(fromByteCount: $0.responseBodySize))
            }.width(min: 54, ideal: 64, max: 140)
        }
        .onChange(of: sortOrder) {
            viewModel.sortDescriptors = $0.map(NSSortDescriptor.init)
        }
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
            ConsoleTableView(viewModel: viewModel.list, selection: .constant(nil))
                .previewLayout(.fixed(width: 1200, height: 800))
        }
        Group {
            let viewModel = ConsoleViewModel(store: .mock)
            let _ = viewModel.mode = .tasks
            ConsoleTableView(viewModel: viewModel.list, selection: .constant(nil))
                .previewLayout(.fixed(width: 1200, height: 800))
        }
    }
}
#endif
#endif
