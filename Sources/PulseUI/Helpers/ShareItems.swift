// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
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
    init(messages store: LoggerStore) {
        let messages = (try? store.allMessages()) ?? []
        let text = ConsoleShareService.format(messages)
        self.init([text])
    }
}

enum ConsoleShareService {
    static func format(_ messages: [LoggerMessageEntity]) -> String {
        var output = ""
        for message in messages {
            output.append(format(message: message))
            output.append("\n")
        }
        return output
    }

    private static func format(message: LoggerMessageEntity) -> String {
        let title = "\(dateFormatter.string(from: message.createdAt)) [\(message.level)]-[\(message.label)] \(message.text)"
        if let task = message.task {
            return title + "\n\n" + share(task, output: .plainText)
        } else {
            return title
        }
    }

    static func share(_ messages: [LoggerMessageEntity]) -> ShareItems {
        let tempDir = TemporaryDirectory()
        let allLogsUrl = tempDir.url.appendingPathComponent("logs.txt")
        let allLogs = format(messages).data(using: .utf8) ?? Data()
        try? allLogs.write(to: allLogsUrl)
        return ShareItems([allLogsUrl], cleanup: tempDir.remove)
    }

    static func share(_ message: LoggerMessageEntity) -> String {
        if let task = message.task {
            return share(task, output: .plainText) // this should never happen
        } else {
            return message.text
        }
    }

    static func share(_ task: NetworkTaskEntity, output: NetworkMessageRenderType) -> String {
        switch output {
        case .plainText: return Render.asPlainText(task: task)
        case .markdown: return Render.asMarkdown(task: task)
        case .html: return Render.asHTML(task: task)
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
            .appendingPathComponent("com.github.kean.logger", isDirectory: true)
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
    formatter.dateFormat = "yyyy-MM-dd-HH-mm"
    return formatter.string(from: Date())
}
