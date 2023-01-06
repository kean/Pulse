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

    private func makeDetails() -> NSAttributedString {
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
