// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Combine

#if os(iOS)

@available(iOS 13.0, *)
struct SearchBar: View {
    let title: String
    @Binding var text: String
    var onEditingChanged: ((_ isEditing: Bool) -> Void)?

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").opacity(0.33)
            textField
            if !text.isEmpty { buttonClear }
        }
        .addSearchBarIshBackground(padding: 8)
    }

    private var textField: some View {
        TextField(title, text: $text, onEditingChanged: { onEditingChanged?($0) })
            .disableAutocorrection(true)
            .autocapitalization(.none)
    }

    private var buttonClear: some View {
        Button(action: { self.text = "" }) {
            Image(systemName: "xmark.circle.fill")
        }
        .foregroundColor(.secondaryFill)
        .buttonStyle(PlainButtonStyle())
    }
}

#endif

#if os(macOS)

@available(iOS 13.0, *)
struct SearchBar: NSViewRepresentable {
    let title: String
    @Binding var text: String
    let imageName: String?
    var onEditingChanged: ((_ isEditing: Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onReturn: (() -> Void)?
    private let onFind: PassthroughSubject<Void, Never>
    
    init(title: String,
         text: Binding<String>,
         imageName: String? = nil,
         onFind: PassthroughSubject<Void, Never> = .init(),
         onEditingChanged: ((Bool) -> Void)? = nil,
         onCancel: (() -> Void)? = nil,
         onReturn: (() -> Void)? = nil)
    {
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
        let searchField = NSSearchField()
        searchField.placeholderString = title
        searchField.delegate = context.coordinator
        searchField.translatesAutoresizingMaskIntoConstraints = false

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
        nsView.stringValue = text
    }
}

#endif

#if os(iOS) || os(macOS)

/// TODO: move to SwiftUI extension, make it a component?
@available(iOS 13.0, *)
extension View {
    func addSearchBarIshBackground(padding p: CGFloat = 9) -> some View {
        padding(p)
        .background(Color.secondaryFill)
        .cornerRadius(8)
    }
}

#endif
