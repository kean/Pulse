// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Pulse
import Foundation

#if os(iOS) || os(macOS)

enum Render {
    static func asPlainText(task: NetworkTaskEntity) -> String {
        render(task: task, using: PlainTextRenderer())
    }

    static func asMarkdown(task: NetworkTaskEntity) -> String {
        render(task: task, using: MarkdownRenderer())
    }

    static func asHTML(task: NetworkTaskEntity) -> String {
        render(task: task, using: HTMLRenderer(error: task.decodingError))
    }

    private static func render(task: NetworkTaskEntity, using renderer: Renderer) -> String {
        // Summary
        let viewModel = NetworkInspectorSummaryViewModel(task: task)
        renderer.add(viewModel.summaryViewModel, isSecondaryTitle: false)
        renderer.add(viewModel.errorModel, isSecondaryTitle: false)

        if let requestSummary = viewModel.originalRequestSummary {
            renderer.add(title: "Request")
            renderer.add(requestSummary)
            renderer.add(viewModel.originalRequestHeaders)
            renderer.add(viewModel.requestBodySection)
            renderer.add(viewModel.originalRequestParameters)
            if let body = task.requestBody?.data, !body.isEmpty {
                renderer.addSecondaryTitle("Request Body")
                renderer.add(data: body)
            }
        }

        if let responseSummary = viewModel.responseSummary {
            renderer.add(title: "Response")
            renderer.add(responseSummary)
            renderer.add(viewModel.responseHeaders)
            renderer.add(viewModel.responseBodySection)
            if let body = task.responseBody?.data, !body.isEmpty {
                renderer.addSecondaryTitle("Response Body")
                renderer.add(data: body)
            }
        }

        renderer.add(title: "Details")
        renderer.add(viewModel.timingDetailsViewModel)
        if let transferModel = viewModel.transferViewModel {
            renderer.add(KeyValueSectionViewModel(title: "Sent Data", color: .gray, items: [
                ("Total Bytes Sent", transferModel.totalBytesSent),
                ("Headers Sent", transferModel.headersBytesSent),
                ("Body Sent", transferModel.bodyBytesSent),
                ("Total Bytes Received", transferModel.totalBytesReceived),
                ("Headers Received", transferModel.headersBytesReceived),
                ("Body Received", transferModel.bodyBytesReceived)
            ]))
        }

        return renderer.finalize(title: "Request Log")
    }
}

private protocol Renderer {
    func add(title: String)
    func addSecondaryTitle(_ title: String)
    func add(data: Data)
    func add(_ keyValueViewModel: KeyValueSectionViewModel?, isSecondaryTitle: Bool)

    func finalize(title: String) -> String
}

extension Renderer {
    func add(_ keyValueViewModel: KeyValueSectionViewModel?) {
        add(keyValueViewModel, isSecondaryTitle: true)
    }
}

private final class PlainTextRenderer: Renderer {
    private var contents = ""

    func anchor(for title: String) -> String {
        title.replacingOccurrences(of: " ", with: "_").lowercased()
    }

    func add(title: String) {
        contents.append("## \(title)\n\n")
    }

    func addSecondaryTitle(_ title: String) {
        contents.append("#### \(title)\n\n")
    }

    func add(data: Data) {
        contents.append(prettifyJSON(data))
        contents.append("\n\n")
    }

    func add(_ keyValueViewModel: KeyValueSectionViewModel?, isSecondaryTitle: Bool = true) {
        guard let model = keyValueViewModel else { return }
        if isSecondaryTitle {
            addSecondaryTitle(model.title)
        } else {
            add(title: model.title)
        }
        if model.items.isEmpty {
            contents.append("Empty\n")
        } else {
            for item in model.items {
                contents.append("- \(item.0): \(item.1 ?? "–")")
                contents.append("\n")
            }
        }
        contents.append("\n")
    }

    func finalize(title: String) -> String {
        contents
    }
}

private final class MarkdownRenderer: Renderer {
    private var contents = ""
    private var toc = ""

    func anchor(for title: String) -> String {
        title.replacingOccurrences(of: " ", with: "_").lowercased()
    }

    func add(title: String) {
        if !toc.isEmpty {
            toc.append("\n")
        }
        toc.append("- [**\(title)**](\(anchor(for: title)))")
        contents.append("## \(title)\n\n")
    }

    func addSecondaryTitle(_ title: String) {
        toc.append("\n  - [\(title)](\(anchor(for: title)))")
        contents.append("#### \(title)\n\n")
    }

    func add(data: Data) {
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        contents.append("```\(json != nil ? "json" : "")\n")
        contents.append(prettifyJSON(data))
        contents.append("\n")
        contents.append("```")
        contents.append("\n\n")
    }

    func add(_ keyValueViewModel: KeyValueSectionViewModel?, isSecondaryTitle: Bool = true) {
        guard let model = keyValueViewModel else { return }
        if isSecondaryTitle {
            addSecondaryTitle(model.title)
        } else {
            add(title: model.title)
        }
        if model.items.isEmpty {
            contents.append("Empty\n")
        } else {
            for item in model.items {
                contents.append("- **\(item.0)**: \(item.1 ?? "–")")
                contents.append("\n")
            }
        }
        contents.append("\n")
    }

    func finalize(title: String) -> String {
        "# \(title)\n\n\(toc)\n\n\(contents)"
    }
}

private final class HTMLRenderer: Renderer {
    private var contents = ""
    private var toc = [ToCItem]()
    private var error: NetworkLogger.DecodingError?

    init(error: NetworkLogger.DecodingError?) {
        self.error = error
    }

    struct ToCItem {
        let level: Int
        let title: String
    }

    func anchor(for title: String) -> String {
        title.replacingOccurrences(of: " ", with: "_").lowercased()
    }

    func add(title: String) {
        toc.append(ToCItem(level: 2, title: title))
        contents.append("<h2 id='\(anchor(for: title))'>\(title)</h2>")
    }

    func addSecondaryTitle(_ title: String) {
        toc.append(ToCItem(level: 3, title: title))
        contents.append("<h3 id='\(anchor(for: title))'>\(title)</h3>")
    }

    func add(data: Data) {
        contents.append("<pre>")
        contents.append("<code>")
        contents.append(makePre(data: data))
        contents.append("</code>")
        contents.append("</pre>")
    }

    private func makePre(data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return String(data: data, encoding: .utf8) ?? "Data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .memory))"
        }
        let renderer = HTMLJSONRender()
        let printer = JSONPrinter(renderer: renderer)
        printer.render(json: json, error: error)
        return renderer.make()
    }

    func add(_ keyValueViewModel: KeyValueSectionViewModel?, isSecondaryTitle: Bool = true) {
        guard let model = keyValueViewModel else { return }
        if isSecondaryTitle {
            addSecondaryTitle(model.title)
        } else {
            add(title: model.title)
        }
        if model.items.isEmpty {
            contents.append("<p>Empty</p>")
        } else {
            contents.append("<ul>")
            for item in model.items {
                contents.append("<li><strong>\(item.0)</strong>: \(item.1 ?? "–")</li>")
                contents.append("\n")
            }
            contents.append("</ul>")
        }
        contents.append("\n")
    }

    func finalize(title: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(title)</title>
            \(style)
        </head>
        <main>
        \(makeToC())
        \(contents)
        </main>
        </html>
        """
    }

    private func makeToC() -> String {
        guard !toc.isEmpty else {
            return ""
        }
        var rows = [[ToCItem]]()
        var index = 0
        while index < toc.count {
            var row = [ToCItem]()
            row.append(toc[index])
            index += 1
            while index < toc.count, toc[index].level == 3 {
                row.append(toc[index])
                index += 1
            }
            rows.append(row)
        }
        var output = "<ul>"
        for row in rows {
            var li = "<li>"
            let (head, tail) = (row.first!, row.dropFirst())
            li.append("<strong><a href='#\(anchor(for: head.title))'>\(head.title)</a></strong>")
            var tailsItems = [String]()
            if !tail.isEmpty {
                li.append(":")
                for item in tail {
                    tailsItems.append(" <a href='#\(anchor(for: item.title))'>\(item.title)</a>")
                }
            }
            li.append(tailsItems.joined(separator: " · "))
            li.append("</li>")
            output.append(li)
        }
        output.append("</ul>")
        return output
    }
}

private let style = """
<style>
body {
    font: 400 16px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro Icons","Helvetica Neue",Helvetica,Arial,sans-serif;
    background-color: #FDFDFD;
    color: #353535;
  }
  pre {
    font-family: 'SF Mono', Menlo, monospace, Courier, Consolas, "Liberation Mono", monospace;
    font-size: 14px;
  }
  h2 {
    margin-top: 30px;
    padding-bottom: 8px;
    border-bottom: 2px solid #DDDDDD;
    font-weight: 600;
    font-size: 34px;
  }
  ul {
    list-style: none;
    padding-left: 0;
  }
  li {
    overflow-wrap: break-word;
  }
  strong {
    font-weight: 600;
    color: #737373;
  }
  main {
    max-width: 900px;
    padding: 15px;
  }
  pre {
    padding: 8px;
    border-radius: 8px;
    background-color: #FDFDFD;
  }
  a {
    color: #0066FF;
  }
  .s { color: rgb(255, 45, 85); }
  .o { color: rgb(0, 122, 255); }
  .n { color: rgb(191, 90, 242); }
  .err { background-color: red; }
  @media (prefers-color-scheme: dark) {
    body {
      background-color: #211F1E;
      color: #DFDFDF;
    }
    strong {
      color: #878787;
    }
    h2 {
      border-bottom: 2px solid #3C3A38;
    }
    pre {
      background-color: #2C2A28;
    }
    a {
      color: #67A6F8;
    }
    .s { color: rgb(255, 55, 95); }
    .o { color: rgb(10, 132, 255); }
    .n { color: rgb(175, 82, 222); }
  }
}
</style>
"""

#endif
