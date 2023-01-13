// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

#if os(iOS)
import PDFKit
#endif

enum TextUtilities {
    static func plainText(from string: NSAttributedString) -> String {
        string.string
    }

    static func html(from string: NSAttributedString) throws -> Data {
        let range = NSRange(location: 0, length: string.length)
        let data = try string.data(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.html
        ])
        guard var html = String(data: data, encoding: .utf8) else {
            return data
        }
        func insert(_ string: String, at index: String.Index) {
            html.insert(contentsOf: "\n\(string)", at: index)
        }

        // TODO: Use JavaScriptCore and DOM to perform these manipulations

        if let range = html.firstRange(of: "<head>") {
            insert(#"<meta name="viewport" content="width=device-width, initial-scale=1">"#, at: range.upperBound)
            insert(#"<meta name="generator" content="Pulse">"#, at: range.upperBound)
        }
        if let range = html.firstRange(of: "<style type=\"text/css\">") {
            insert(#"span { line-height: 1.4; }"#, at: range.upperBound)
            insert(#"body { word-wrap: break-word;  padding: 8px; }"#, at: range.upperBound)
        }
        let regular = #"font-family: 'SF Pro Text', -apple-system, sans-serif"#
        let mono = #"font-family: 'SF Mono', SFMono-Regular, ui-monospace, Menlo, monospace;"#
        html = html.replacingOccurrences(of: #"font-family: '.SFUI-Regular'"#, with: regular)
        html = html.replacingOccurrences(of: #"font-family: '.SFUI-Medium'"#, with: regular)
        html = html.replacingOccurrences(of: #"font-family: '.SFUI-Semibold'"#, with: regular)
        html = html.replacingOccurrences(of: #"font-family: '.AppleSystemUIFontMonospaced-Regular'"#, with: mono)
        html = html.replacingOccurrences(of: #"font-family: '.AppleSystemUIFontMonospaced-Semibold'"#, with: mono)
        html = html.replacingOccurrences(of: #"font-family: '.AppleSystemUIFontMonospaced-Medium'"#, with: mono)
        return html.data(using: .utf8) ?? data
    }

    /// Renders the given attributed string as PDF
#if os(iOS)
    static func pdf(from string: NSAttributedString) throws -> Data {
        let string = NSMutableAttributedString(attributedString: string)
        string.enumerateAttribute(.font, in: NSRange(location: 0, length: string.length)) { font, range, _ in
            guard let font = font as? UXFont else { return }
            let scaledFont = UXFont(descriptor: font.fontDescriptor, size: (font.pointSize * 0.7).rounded())
            string.addAttribute(.font, value: scaledFont, range: range)
        }
        let formatter = UISimpleTextPrintFormatter(attributedText: string)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageSize = CGSize(width: 612, height: 792) // US letter size
        let pageMargins = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)

        // Calculate the printable rect from the above two
        let printableRect = CGRect(x: pageMargins.left, y: pageMargins.top, width: pageSize.width - pageMargins.left - pageMargins.right, height: pageSize.height - pageMargins.top - pageMargins.bottom)
        let paperRect = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)

        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let data = NSMutableData()

        UIGraphicsBeginPDFContextToData(data, paperRect, nil)
        renderer.prepare(forDrawingPages: NSMakeRange(0, renderer.numberOfPages))

        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0  ..< renderer.numberOfPages  {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()

        return data as Data
    }
#endif
}
