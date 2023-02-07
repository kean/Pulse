// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkDetailsView: View {
    private var title: String
    private let viewModel: NetworkDetailsViewModel?
    @State private var isShowingShareSheet = false

    init(title: String, viewModel: @escaping () -> KeyValueSectionViewModel?) {
        self.title = title
        self.viewModel = NetworkDetailsViewModel {
            viewModel().map { viewModel in
                TextRenderer().render(viewModel.items, color: viewModel.color)
            }
        }
    }

    init(title: String, text: @escaping () -> NSAttributedString?) {
        self.title = title
        self.viewModel = NetworkDetailsViewModel(text)
    }

    var body: some View {
        contents.inlineNavigationTitle(title)
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
