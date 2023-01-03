// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

struct NetworkInspectorRequestDetailsView: View {
    let viewModel: NetworkInspectorRequestDetailsViewModel

    var body: some View {
        NetworkDetailsView(title: "Request", text: viewModel.details)
    }
}

final class NetworkInspectorRequestDetailsViewModel {
    private let task: NetworkTaskEntity
    private(set) lazy var details = makeDetails()

    init(task: NetworkTaskEntity) {
        self.task = task
    }

    private func makeDetails() -> NSAttributedString {
        guard let url = URL(string: task.url ?? "") else {
            return NSAttributedString(string: "Invalid URL")
        }

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UXColor.label,
            .font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .regular)
        ]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UXColor.label,
            .font: UXFont.monospacedSystemFont(ofSize: FontSize.body + 2, weight: .semibold),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.paragraphSpacing = 8
                return style
            }()
        ]

        let string = NSMutableAttributedString()

        string.append(url.absoluteString, bodyAttributes)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return string
        }

        string.append("\n", bodyAttributes)

        let items: [(String, String?)] = [
            ("Scheme", components.scheme),
            ("Port", components.port?.description),
            ("User", components.user),
            ("Password", components.password),
            ("Host", components.host),
            ("Path", components.path),
            ("Query", components.query),
            ("Fragment", components.fragment)
        ]

        let section = KeyValueSectionViewModel(title: "", color: .blue, items: items.filter { $0.1?.isEmpty == false })
        string.append("\nURL Components\n", titleAttributes)
        string.append(section.asAttributedString())

        if var queryItems = KeyValueSectionViewModel.makeQueryItems(for: url, action: {}) {
            queryItems.color = .purple
            string.append("\nQuery Items\n", titleAttributes)
            string.append(queryItems.asAttributedString())
        }

        if let request = task.originalRequest {
            string.append("\nRequest Parameters\n", titleAttributes)
            var section = KeyValueSectionViewModel.makeParameters(for: request)
            section.items = [
                ("Task", task.type?.urlSessionTaskClassName)
            ] + section.items
            section.color = .indigo
            string.append(section.asAttributedString())
        }
        string.addAttributes([.underlineColor: UXColor.clear])

        return string
    }
}

struct NetworkInspectorRequestDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorRequestDetailsView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }
    }
}
