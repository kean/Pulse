// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(*, deprecated, message: "Deprecated")
struct NetworkDetailsView: View {
    private var title: String
    private let viewModel: NetworkDetailsViewModel?
    @State private var isShowingShareSheet = false

    init(title: String, viewModel: @escaping () -> KeyValueSectionViewModel?) {
        self.title = title
        self.viewModel = NetworkDetailsViewModel {
            viewModel().map {
                TextRenderer().render($0.items, color: $0.color)
            }
        }
    }

    init(title: String, text: @escaping () -> NSAttributedString?) {
        self.title = title
        self.viewModel = NetworkDetailsViewModel(text)
    }

    var body: some View {
        contents
            .backport.navigationTitle(title)
    }

    @ViewBuilder
    private var contents: some View {
        if let viewModel = viewModel?.text, !viewModel.isEmpty {
            RichTextView(viewModel: viewModel)
        } else {
            PlaceholderView(imageName: "nosign", title: "Empty")
        }
    }
}

final class NetworkDetailsViewModel {
    private(set) lazy var text = makeString().map { RichTextViewModel(string: $0) }
    private let makeString: () -> NSAttributedString?

    init(_ closure: @escaping () -> NSAttributedString?) {
        self.makeString = closure
    }
}

#if DEBUG
struct NetworkDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkDetailsView(title: "Section") {
                    KeyValueSectionViewModel.makeComponents(for: URL(string: LoggerStore.preview.entity(for: .login).url!)!)
                }
            }
#if !os(watchOS)
            NavigationView {
                NetworkDetailsView(title: "JWT") {
                    KeyValueSectionViewModel.makeDetails(for: jwt)
                }
            }
            .previewDisplayName("JWT")
#endif
        }
    }
}

private let jwt = try! JWT("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
#endif
