// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)

import UIKit

@available(iOS 13.0, *)
struct ShareView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    private let cleanup: () -> Void

    // TODO: remove this variant
    init(activityItems: [Any]) {
        self.activityItems = activityItems
        self.cleanup = {}
    }

    init(_ items: ShareItems) {
        self.activityItems = items.items
        self.cleanup = items.cleanup
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { _, _, _, _ in
            cleanup()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareView>) {
    }
}

@available(iOS 13.0, *)
struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
#endif
