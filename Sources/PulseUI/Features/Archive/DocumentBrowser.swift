// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import UIKit
import SwiftUI
import Pulse
import UniformTypeIdentifiers

final class DocumentBrowserViewController: UIDocumentPickerViewController, UIDocumentPickerDelegate, UIDocumentBrowserViewControllerDelegate {

    // This key is used to encode the bookmark data of the URL of the opened document as part of the state restoration data.
    static let bookmarkDataKey = "bookmarkData"

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        view.tintColor = .systemBlue
    }

    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // Do nothing
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // Do nothing
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
            vc.onDeinit {
                documentURL.stopAccessingSecurityScopedResource()
            }
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true, completion: nil)
        } catch {
            documentURL.stopAccessingSecurityScopedResource()

            let vc = UIAlertController(title: "Failed to open store", message: error.localizedDescription, preferredStyle: .alert)
            vc.addAction(.init(title: "Ok", style: .cancel, handler: nil))
            present(vc, animated: true, completion: nil)
        }
    }
}

#endif
