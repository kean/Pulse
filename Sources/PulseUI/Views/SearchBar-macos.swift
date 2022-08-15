// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Combine

#if os(macOS)

struct SearchBar: NSViewRepresentable {
    let title: String?
    @Binding var text: String
    let imageName: String?
    var onEditingChanged: ((_ isEditing: Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onReturn: (() -> Void)?
    private let onFind: PassthroughSubject<Void, Never>

    init(title: String?,
         text: Binding<String>,
         imageName: String? = nil,
         onFind: PassthroughSubject<Void, Never> = .init(),
         onEditingChanged: ((Bool) -> Void)? = nil,
         onCancel: (() -> Void)? = nil,
         onReturn: (() -> Void)? = nil) {
        self.title = title
        self._text = text
        self.imageName = imageName
        self.onFind = onFind
        self.onEditingChanged = onEditingChanged
        self.onCancel = onCancel
        self.onReturn = onReturn
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        var onEditingChanged: ((_ isEditing: Bool) -> Void)?
        var onCancel: (() -> Void)?
        var onReturn: (() -> Void)?
        var cancellables: [AnyCancellable] = [] // TODO: refactor

        init(parent: SearchBar) {
            self.onEditingChanged = parent.onEditingChanged
            self.onCancel = parent.onCancel
            self.onReturn = parent.onReturn
            self._text = parent.$text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                self.text = textField.stringValue
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            onEditingChanged?(true)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            onEditingChanged?(false)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSSearchField.cancelOperation(_:)) {
                onCancel?()
                onEditingChanged?(false)
                return false
            } else if commandSelector == #selector(NSSearchField.insertNewline(_:)) {
                onReturn?()
                return true
            }
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = FocusAwareSearchField()
        searchField.delegate = context.coordinator
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.onFocusChange = onEditingChanged

        if let imageName = self.imageName {
            (searchField.cell as? NSSearchFieldCell)?.searchButtonCell?.image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)
        }

        let constraint = searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        constraint.priority = .init(rawValue: 249)
        constraint.isActive = true

        onFind.sink { [weak searchField] in
            // TODO: refactor
            guard let searchField = searchField, searchField.window?.isKeyWindow ?? false else { return }
            _ = searchField.becomeFirstResponder()
        }.store(in: &context.coordinator.cancellables)
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.placeholderString = title
        nsView.stringValue = text
    }
}

private class FocusAwareSearchField: NSSearchField {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        onFocusChange?(true)
        return super.becomeFirstResponder()
    }
}

#endif
