// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct NetworkDetailsView: View {
    private var title: String
    private let text: NSAttributedString
    @State private var isShowingShareSheet = false

    init(viewModel: KeyValueSectionViewModel) {
        self.title = viewModel.title
        self.text = viewModel.asAttributedString()
    }

    init(title: String, text: NSAttributedString) {
        self.title = title
        self.text = text
    }

    func title(_ title: String) -> NetworkDetailsView {
        var copy = self
        copy.title = title
        return copy
    }

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle(title)
            .navigationBarItems(trailing: ShareButton {
                isShowingShareSheet = true
            })
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [text])
            }
    }
    #else
    var body: some View {
        contents
    }
    #endif

    @ViewBuilder
    private var contents: some View {
        if text.string.isEmpty {
            PlaceholderView(imageName: "folder", title: "Empty")
        } else {
            #if os(watchOS) || os(tvOS)
            RichTextView(viewModel: .init(string: text.string))
            #else
            RichTextView(viewModel: {
                let viewModel = RichTextViewModel(string: text)
                viewModel.isAutomaticLinkDetectionEnabled = false
                return viewModel
            }())
            #endif
        }
    }
}

#if DEBUG
struct NetworkDetailsView_Previews: PreviewProvider {
    static var previews: some View {
#if !os(watchOS)
        NetworkDetailsView(title: "JWT", text: KeyValueSectionViewModel.makeDetails(for: jwt))
#endif
    }
}

private let jwt = try! JWT("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
#endif
