// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct ConsoleTableView: View {
    let viewModel: ConsoleListViewModel
    @Binding var selection: NSManagedObjectID?

    var body: some View {
        if viewModel.entities is [LoggerMessageEntity] {
            ConsoleMessageTableView(viewModel: viewModel, selection: $selection)
        } else if viewModel.entities is [NetworkTaskEntity] {
            Text("ConsoleNetworkTableView")
        } else {
            fatalError("Unsupported entities: \(viewModel.entities)")
        }
    }
}

#warning("add a way to cutomize which rows are sown")
#warning("add network table view")

private struct ConsoleMessageTableView: View {
    @ObservedObject var viewModel: ConsoleListViewModel
    @Binding var selection: NSManagedObjectID?
    @State private var sortOrder = [SortDescriptor<LoggerMessageEntity>(\.createdAt, order: .reverse)]

    var body: some View {
        Table(viewModel.entities as! [LoggerMessageEntity], selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date & Time", value: \.createdAt) {
                Text(dateAndTimeFormatter.string(from: $0.createdAt))
            }.width(ideal: 162, max: 162)
            TableColumn("Level", value: \.level) {
                Text($0.logLevel.name)
            }.width(ideal: 50, max: 54)
            TableColumn("Label", value: \.label) {
                Text($0.label)
            }.width(ideal: 68)
            TableColumn("Message", value: \.text)
                .width(ideal: 600)
            TableColumn("File", value: \.file)
                .width(ideal: 80)
            TableColumn("Function", value: \.function)
                .width(ideal: 100)
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

struct ConsoleTableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleTableView(viewModel: ConsoleViewModel(store: .mock).list, selection: .constant(nil))
                .previewLayout(.fixed(width: 1200, height: 800))
        }
    }
}
#endif
