// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Combine

#if os(iOS)

struct WrappedTextView: UIViewRepresentable {
    let viewModel: RichTextViewModel

    @ObservedObject private var settings = UserSettings.shared

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTapped: ((URL) -> Bool)?
        var cancellables: [AnyCancellable] = []

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let onLinkTapped = onLinkTapped, onLinkTapped(URL) {
                return false
            }
            if let (title, message) = parseTooltip(URL) {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(.init(title: "Done", style: .cancel))
                UIApplication.keyWindow?.rootViewController?.present(alert, animated: true)

                return false
            }
            return true
        }
    }

    func makeUIView(context: Context) -> UXTextView {
        let textView: UITextView
        if #available(iOS 16, *) {
            // Disables the new TextKit 2 which is extremely slow on iOS 16
            textView = UITextView(usingTextLayoutManager: false)
        } else {
            textView = UITextView()
        }
        configureTextView(textView)
        textView.delegate = context.coordinator
        textView.attributedText = viewModel.originalText
        viewModel.textView = textView
        return textView
    }

    func updateUIView(_ textView: UXTextView, context: Context) {
        textView.isAutomaticLinkDetectionEnabled = settings.isLinkDetectionEnabled && viewModel.isLinkDetectionEnabled
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onLinkTapped = viewModel.onLinkTapped
        return coordinator
    }
}

#elseif os(macOS)

struct WrappedTextView: NSViewRepresentable {
    let viewModel: RichTextViewModel

    @ObservedObject private var settings = UserSettings.shared

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onLinkTapped: ((URL) -> Bool)?
        var cancellables: [AnyCancellable] = []

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else {
                return false
            }
            if let onLinkTapped = onLinkTapped, onLinkTapped(url) {
                return true
            }
            return false
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
#if PULSE_STANDALONE_APP
        let scrollView = WrappedTextView.createScrollableTextView(viewModel: viewModel, coordinator: context.coordinator)
#else
        let scrollView = UXTextView.scrollableTextView()
#endif
        let textView = scrollView.documentView as! UXTextView

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        configureTextView(textView)
        if viewModel.isLineNumberRulerEnabled {
            scrollView.automaticallyAdjustsContentInsets = false
            textView.textContainerInset = CGSize(width: 0, height: 10)
        }

        textView.delegate = context.coordinator

        textView.attributedText = viewModel.originalText

        viewModel.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        textView.isAutomaticLinkDetectionEnabled = settings.isLinkDetectionEnabled && viewModel.isLinkDetectionEnabled
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onLinkTapped = viewModel.onLinkTapped
        return coordinator
    }
}
#endif

private func configureTextView(_ textView: UXTextView) {
    textView.isSelectable = true
    textView.isEditable = false
    textView.linkTextAttributes = [
        .underlineStyle: 1
    ]
    textView.backgroundColor = .clear

#if os(iOS)
    textView.keyboardDismissMode = .interactive
    textView.alwaysBounceVertical = true
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.adjustsFontForContentSizeCategory = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
#endif

#if os(macOS)
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.textContainerInset = NSSize(width: 10, height: 10)
#endif
}

private func parseTooltip(_ url: URL) -> (title: String?, message: String)? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.scheme == "pulse",
          components.path == "tooltip",
          let queryItems = components.queryItems,
          let message = queryItems.first(where: { $0.name == "message" })?.value else {
        return nil
    }
    let title = queryItems.first(where: { $0.name == "title" })?.value
    return (title: title, message: message)
}

#endif
