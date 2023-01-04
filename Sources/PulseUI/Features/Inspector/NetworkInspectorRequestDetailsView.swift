// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkInspectorRequestDetailsView: View {
    let viewModel: NetworkInspectorRequestDetailsViewModel

    var body: some View {
        NetworkDetailsView(title: "Request") { viewModel.details }
    }
}

final class NetworkInspectorRequestDetailsViewModel {
    private let request: NetworkRequestEntity
    private(set) lazy var details = makeDetails()

    init(request: NetworkRequestEntity) {
        self.request = request
    }

    #warning("TODO: perform rendering using TextRenderer (?)")
    private func makeDetails() -> NSAttributedString {
        guard let url = URL(string: request.url ?? "") else {
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
        if let section = KeyValueSectionViewModel.makeComponents(for: url) {
            string.append("\nURL Components\n", titleAttributes)
            string.append(section.asAttributedString())
        }

        if let queryItems = KeyValueSectionViewModel.makeQueryItems(for: url) {
            string.append("\nQuery Items\n", titleAttributes)
            string.append(queryItems.asAttributedString())
        }

        string.append("\nRequest Parameters\n", titleAttributes)

        let parametersSection = KeyValueSectionViewModel.makeParameters(for: request)
        string.append(parametersSection.asAttributedString())

        string.addAttributes([.underlineColor: UXColor.clear])

        return string
    }
}

#if DEBUG
struct NetworkInspectorRequestDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorRequestDetailsView(viewModel: .init(request: LoggerStore.preview.entity(for: .login).originalRequest!))
        }
    }
}
#endif
