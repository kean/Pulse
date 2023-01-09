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
#if os(iOS)
        if #available(iOS 14.0, *) {
            contents.navigationBarTitle(title, displayMode: .inline)
        } else {
            contents.backport.navigationTitle(title)
        }
#else
        contents.backport.navigationTitle(title)
#endif
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
