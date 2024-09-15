// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(visionOS)
import PDFKit

package struct PDFKitRepresentedView: UIViewRepresentable {
    package let document: PDFDocument

    package init(document: PDFDocument) {
        self.document = document
    }

    package func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        return pdfView
    }

    package func updateUIView(_ view: PDFView, context: Context) {
        // Do nothing
    }
}
#elseif os(macOS)
import PDFKit

package struct PDFKitRepresentedView: NSViewRepresentable {
    package let document: PDFDocument

    package init(document: PDFDocument) {
        self.document = document
    }

    package func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }

    package func updateNSView(_ view: PDFView, context: Context) {
        // Do nothing
    }
}
#endif
