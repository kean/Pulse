// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import UIKit
import SwiftUI
import CoreData
import PulseUI
import PulseCore

final class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, UIViewControllerTransitioningDelegate {

    // This key is used to encode the bookmark data of the URL of the opened document as part of the state restoration data.
    static let bookmarkDataKey = "bookmarkData"

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        allowsDocumentCreation = false
        allowsPickingMultipleItems = false
        view.tintColor = .systemBlue
    }

    // MARK: UIDocumentBrowserViewControllerDelegate

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }

        // When the user has chosen an existing document, a new `DocumentViewController` is presented for the first document that was picked.
        presentDocument(at: sourceURL)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {

        // When a new document has been imported by the `UIDocumentBrowserViewController`, a new `DocumentViewController` is presented as well.
        presentDocument(at: destinationURL)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, applicationActivitiesForDocumentURLs documentURLs: [URL]) -> [UIActivity] {
        // Whenever one or more items are being shared by the user, the default activities of the `UIDocumentBrowserViewController` can be augmented
        // with custom ones. In this case, no additional activities are added.
        return []
    }

    // MARK: UIViewControllerTransitioningDelegate

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // Since the `UIDocumentBrowserViewController` has been set up to be the transitioning delegate of `DocumentViewController` instances (see
        // implementation of `presentDocument(at:)`), it is being asked for a transition controller.
        // Therefore, return the transition controller, that previously was obtained from the `UIDocumentBrowserViewController` when a
        // `DocumentViewController` instance was presented.
        return transitionController
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // The same zoom transition is needed when closing documents and returning to the `UIDocumentBrowserViewController`, which is why the the
        // existing transition controller is returned here as well.
        return transitionController
    }

    // MARK: Document Presentation

    var transitionController: UIDocumentBrowserTransitionController?

    // MARK: Document Presentation

    func presentDocument(at documentURL: URL, animated: Bool = true) {
        guard documentURL.startAccessingSecurityScopedResource() else {
            return
        }

        do {
            let store = try LoggerStore(storeURL: documentURL)
            let vc = UIHostingController(rootView: MainView(store: store, onDismiss: { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }))
            vc.transitioningDelegate = self
            transitionController = transitionController(forDocumentAt: documentURL)
            vc.onDeinit {
                documentURL.stopAccessingSecurityScopedResource()
            }
            vc.modalPresentationStyle = .fullScreen
            transitionController?.targetView = vc.view
            present(vc, animated: true, completion: nil)
        } catch {
            documentURL.stopAccessingSecurityScopedResource()

            let vc = UIAlertController(title: "Failed to open store", message: error.localizedDescription, preferredStyle: .alert)
            vc.addAction(.init(title: "Ok", style: .cancel, handler: nil))
            present(vc, animated: true, completion: nil)
        }
    }
}

extension NSObject {
    static var deinitKey = "ImageDecompressor.isDecompressionNeeded.AssociatedKey"

    class Container {
        let closure: () -> Void

        init(_ closure: @escaping () -> Void) {
            self.closure = closure
        }

        deinit {
            closure()
        }
    }

    func onDeinit(_ closure: @escaping () -> Void) {
        objc_setAssociatedObject(self, &NSObject.deinitKey, Container(closure), .OBJC_ASSOCIATION_RETAIN)
    }
}
