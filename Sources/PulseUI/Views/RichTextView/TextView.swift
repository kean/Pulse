// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(tvOS)
/// A simple text view for rendering attributed strings.
struct TextView: UIViewRepresentable {
    let string: NSAttributedString

    func makeUIView(context: Context) -> UXTextView {
        let textView = UITextView()
        configureTextView(textView)
        textView.attributedText = string
        return textView
    }

    func updateUIView(_ uiView: UXTextView, context: Context) {
        // Do nothing
    }
}
#elseif os(macOS)
struct TextView: NSViewRepresentable {
    let string: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = false
        let textView = scrollView.documentView as! NSTextView
        configureTextView(textView)
        textView.attributedText = string
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Do nothing
    }
}
#elseif os(watchOS)
struct TextView: View {
    let string: NSAttributedString

    var body: some View {
        if let string = try? AttributedString(string, including: \.uiKit) {
            Text(string)
        } else {
            Text(string.string)
        }
    }
}
#endif

#if os(iOS) || os(macOS) || os(tvOS)
private func configureTextView(_ textView: UXTextView) {
    textView.isSelectable = true
    textView.backgroundColor = .clear

#if os(iOS) || os(macOS)
    textView.isEditable = false
    textView.isAutomaticLinkDetectionEnabled = false
#endif

#if os(iOS)
    textView.isScrollEnabled = false
    textView.adjustsFontForContentSizeCategory = true
    textView.textContainerInset = .zero
#endif

#if os(macOS)
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.textContainerInset = .zero
#endif
}
#endif
