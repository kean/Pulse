// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(visionOS)

import WebKit
import UIKit

package struct WebView: UIViewRepresentable {
    package let data: Data
    package let contentType: String

    package init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }

    package func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: .init())
        webView.load(data, mimeType: contentType, characterEncodingName: "UTF8", baseURL: FileManager.default.temporaryDirectory)
        return webView
    }

    package func updateUIView(_ webView: WKWebView, context: Context) {
        // Do nothing
    }
}
#endif

#if os(macOS)

import WebKit
import AppKit

package struct WebView: NSViewRepresentable {
    package let data: Data
    package let contentType: String

    package func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: .init())
        webView.load(data, mimeType: contentType, characterEncodingName: "UTF8", baseURL: FileManager.default.temporaryDirectory)
        return webView
    }

    package func updateNSView(_ nsView: WKWebView, context: Context) {
        // Do nothing
    }
}

#endif
