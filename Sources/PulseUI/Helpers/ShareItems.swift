// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

#if os(iOS) || os(macOS)

enum ShareStoreOutput {
    case store, text
}

struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
    let cleanup: () -> Void

    init(_ items: [Any], cleanup: @escaping () -> Void = { }) {
        self.items = items
        self.cleanup = cleanup
    }
}

extension ShareItems {
    init(store: LoggerStore, output: ShareStoreOutput) {
        let directory = TemporaryDirectory()
        let date = makeCurrentDate()

        let items: [Any]
        switch output {
        case .store:
            if store.isReadonly {
                items = [store.storeURL]
            } else {
                let storeURL = directory.url.appendingPathComponent("logs-\(date).pulse", isDirectory: false)
                _ = try? store.copy(to: storeURL)
                items = [storeURL]
            }
        case .text:
            let messages = (try? store.allMessages()) ?? []
            let text = ConsoleShareService(store: store).format(messages)
            let logsURL = directory.url.appendingPathComponent("logs-\(date).txt")
            try? text.data(using: .utf8)?.write(to: logsURL)
            items = [logsURL]
            break
        }

        self.init(items, cleanup: directory.remove)
    }

    init(messages store: LoggerStore) {
        let messages = (try? store.allMessages()) ?? []
        let text = ConsoleShareService(store: store).format(messages)
        self.init([text])
    }
}

struct ConsoleShareService {
    let store: LoggerStore
    private var context: NSManagedObjectContext { store.viewContext }

    init(store: LoggerStore) {
        self.store = store
    }

    func format(_ messages: [LoggerMessageEntity]) -> String {
        var output = ""
        for message in messages {
            output.append(format(message: message))
            output.append("\n")
        }
        return output
    }

    private func format(message: LoggerMessageEntity) -> String {
        let title = "\(dateFormatter.string(from: message.createdAt)) [\(message.level)]-[\(message.label)] \(message.text)"
        if let request = message.request {
            return title + "\n\n" + share(request, output: .plainText)
        } else {
            return title
        }
    }

    func share(_ messages: [LoggerMessageEntity]) -> ShareItems {
        let tempDir = TemporaryDirectory()
        let allLogsUrl = tempDir.url.appendingPathComponent("logs.txt")
        let allLogs = format(messages).data(using: .utf8) ?? Data()
        try? allLogs.write(to: allLogsUrl)
        return ShareItems([allLogsUrl], cleanup: tempDir.remove)
    }

    func share(_ message: LoggerMessageEntity) -> String {
        if let request = message.request {
            return share(request, output: .plainText) // this should never happen
        } else {
            return message.text
        }
    }

    func share(_ request: LoggerNetworkRequestEntity, output: NetworkMessageRenderType) -> String {
        switch output {
        case .plainText: return Render.asPlainText(request: request, store: store)
        case .markdown: return Render.asMarkdown(request: request, store: store)
        case .html: return Render.asHTML(request: request, store: store)
        }
    }
}

enum NetworkMessageRenderType {
    case plainText
    case markdown
    case html
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
    return formatter
}()

#endif

struct TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

#if os(iOS) || os(macOS)
extension TemporaryDirectory {
    func write(text: String, extension fileExtension: String) -> URL {
        let date = makeCurrentDate()
        let fileURL = url.appendingPathComponent("logs-\(date).\(fileExtension)", isDirectory: false)
        try? text.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }
}
#endif

func makeCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd_HH-mm"
    return formatter.string(from: Date())
}
