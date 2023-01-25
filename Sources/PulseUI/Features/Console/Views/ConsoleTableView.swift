// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

#warning("remove id: usage")

struct ConsoleTableView: View {
    let list: ConsoleListViewModel

    var body: some View {
        if let messages = list.entities as? [LoggerMessageEntity] {
            ConsoleMessageTableView(entities: messages)
        } else if let tasks = list.entities as? [LoggerMessageEntity] {
            Text("Network")
        }
    }
}

#warning("sort per column API?")
#warning("add a way to cutomize which rows are sown")

private struct ConsoleMessageTableView: View {
    let entities: [LoggerMessageEntity]

    @State private var sortOrder = [KeyPathComparator(\LoggerMessageEntity.createdAt)]

    var body: some View {
        Table(entities, sortOrder: $sortOrder) {
            TableColumn("Date & Time", value: \.createdAt) {
                Text(dateAndTimeFormatter.string(from: $0.createdAt))
            }.width(ideal: 162, max: 162)
            TableColumn("Level", value: \.level) {
                Text($0.logLevel.name)
            }.width(ideal: 46, max: 50)
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
            // TODO: commuincate to ViewModel
            print("did change order ", $0)
//            people.sort(using: $0)
        }
    }
}

//case .status: return ""
//case .index: return ""
//case .dateAndTime: return "Date & Time"
//case .date: return "Date"
//case .time: return "Time"
//case .interval: return "Interval"
//case .level: return "Level"
//case .label: return "Label"
//case .message: return "Message"
//case .file: return "File"
//case .function: return "Function"

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
}()

private let dateAndTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()


struct ConsoleTableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleTableView(list: ConsoleViewModel(store: .mock).list)
                .previewLayout(.fixed(width: 1200, height: 800))
        }
    }
}
#endif
