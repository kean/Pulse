// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkRequestInfoCell: View {
    let viewModel: NetworkRequestInfoCellViewModel

    var body: some View {
        NavigationLink(destination: destinationRequestDetails) {
            contents
        }
    }

    private var contents: some View {
        (Text(viewModel.httpMethod).bold() + Text(" ") + Text(viewModel.url))
            .lineLimit(4)
            .font(.callout)
    }

    private var destinationRequestDetails: some View {
        NetworkDetailsView(title: "Request") { viewModel.render() }
    }
}

final class NetworkRequestInfoCellViewModel {
    let httpMethod: String
    let url: String
    let render: () -> NSAttributedString

    init(task: NetworkTaskEntity) {
        self.httpMethod = task.httpMethod ?? "GET"
        self.url = task.url ?? "–"
        self.render = {
            TextRenderer(options: .sharing).render(task, content: .all)
        }
    }

    init(request: NetworkRequestEntity) {
        self.httpMethod = request.httpMethod ?? "GET"
        self.url = request.url ?? "–"
        self.render = { makeDetails(for: request) }
    }
}

private func makeDetails(for request: NetworkRequestEntity) -> NSAttributedString {
    guard let url = URL(string: request.url ?? "") else {
        return NSAttributedString(string: "Invalid URL")
    }
    let renderer = TextRenderer()
    let urlString = renderer.render(url.absoluteString + "\n", role: .body2, style: .monospaced)
    let sections: [NSAttributedString] = [
        KeyValueSectionViewModel.makeComponents(for: url),
        KeyValueSectionViewModel.makeQueryItems(for: url),
        KeyValueSectionViewModel.makeParameters(for: request)
    ].compactMap { $0 }.map { renderer.render($0, style: .monospaced) }

    let strings = [urlString] + sections
    let string = NSMutableAttributedString(attributedString: renderer.joined(strings))
    string.addAttributes([.underlineColor: UXColor.clear])
    return string
}

#if DEBUG
struct NetworkRequestInfoCell_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(MockTask.allEntities, id: \.objectID) { task in
                    NetworkRequestInfoCell(viewModel: .init(task: task))
                }
            }
#if os(macOS)
            .frame(width: MainView.contentColumnWidth)
#endif
        }
    }
}
#endif
