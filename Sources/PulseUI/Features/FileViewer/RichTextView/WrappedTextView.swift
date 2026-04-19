// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct WrappedTextView: UIViewRepresentable {
    let viewModel: RichTextViewModel

    @ObservedObject private var settings = UserSettings.shared

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTapped: ((URL) -> Bool)?
        var cancellables: [AnyCancellable] = []

        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .link(let URL) = textItem.content else { return defaultAction }
            if let onLinkTapped = onLinkTapped, onLinkTapped(URL) {
                return nil
            }
            if let (title, message) = parseTooltip(URL) {
                return UIAction { _ in
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alert.addAction(.init(title: "Done", style: .cancel))
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true)
                }
            }
            return defaultAction
        }

        @available(iOS, deprecated: 17, message: "Use primaryActionFor instead")
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
        // Disables the new TextKit 2 which is extremely slow on iOS 16
        let textView = UITextView(usingTextLayoutManager: false)
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

private func configureTextView(_ textView: UXTextView) {
    textView.isSelectable = true
    textView.isEditable = false
    textView.linkTextAttributes = [
        .underlineStyle: 1
    ]
    textView.backgroundColor = .clear
    textView.alwaysBounceVertical = true
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.adjustsFontForContentSizeCategory = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)

#if os(iOS)
    textView.keyboardDismissMode = .interactive
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
