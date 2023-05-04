// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkCookiesCell: View {
    let viewModel: NetworkCookiesCellViewModel

    var body: some View {
        NavigationLink(destination: destination) {
            NetworkMenuCell(
                icon: "lock.square.stack.fill",
                tintColor: .secondary,
                title: viewModel.title,
                details: viewModel.details
            )
        }
        .foregroundColor(viewModel.isEnabled ? nil : .secondary)
        .disabled(!viewModel.isEnabled)
    }

    private var destination: some View {
        NetworkDetailsView(title: viewModel.title) {
            viewModel.detailsAttributedString
        }
    }
}

struct NetworkCookiesCellViewModel {
    let title: String
    let details: String
    let isEnabled: Bool

    var detailsAttributedString: NSAttributedString {
        makeAttributedString(for: cookies)
    }

    private let cookies: [HTTPCookie]

    init(title: String, headers: [String: String]?, url: URL?) {
        self.title = title
        let cookies = getCookies(from: headers, url: url)
        self.details = "\(cookies.count)"
        self.isEnabled = !cookies.isEmpty
        self.cookies = cookies
    }
}

private func getCookies(from headers: [String: String]?, url: URL?) -> [HTTPCookie] {
    guard let headers = headers, !headers.isEmpty, let url = url else { return [] }
    return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
}

private func makeAttributedString(for cookies: [HTTPCookie]) -> NSAttributedString {
    guard !cookies.isEmpty else {
        return NSAttributedString(string: "Empty") // Should never happen
    }

    var colorIndex = 0
    let colors: [Color] = [.blue, .purple, .orange, .red, .indigo, .green]
    var nextColor: Color {
        defer {
            colorIndex += 1
            if colorIndex == colors.endIndex {
                colorIndex = 0
            }
        }
        return colors[colorIndex]
    }

    let sections = cookies
        .sorted { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending }
        .map { KeyValueSectionViewModel.makeDetails(for: $0, color: nextColor) }
    let renderer = TextRenderer()
    for section in sections {
        renderer.append(renderer.render(section.items, color: section.color, style: .monospaced))
        renderer.addSpacer()
    }
    return renderer.make()
}

#if DEBUG
struct NetworkCookiesCell_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(MockTask.allEntities, id: \.objectID) { task in
                    Section {
                        let url = URL(string: task.url!)!
                        Text(url.absoluteString)
                        NetworkCookiesCell(viewModel: .init(title: "Original Request Cookies", headers: task.originalRequest?.headers, url: url))
                        NetworkCookiesCell(viewModel: .init(title: "Current Request Cookies", headers: task.currentRequest?.headers, url: url))
                        NetworkCookiesCell(viewModel: .init(title: "Response Cookies", headers: task.response?.headers, url: url))
                    }
                }
            }
#if os(macOS)
            .frame(width: 260)
#endif
        }
    }
}
#endif
