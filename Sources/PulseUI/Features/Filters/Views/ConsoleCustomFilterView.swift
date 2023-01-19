// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomFilterView<Pickers: View>: View {
    @Binding private var text: String
    private let onRemove: (() -> Void)?
    private let pickers: () -> Pickers

    @State private var textFieldValue: String

    init(text: Binding<String>,
         onRemove: (() -> Void)?,
         @ViewBuilder pickers: @escaping () -> Pickers) {
        self._text = text
        self.textFieldValue = text.wrappedValue
        self.onRemove = onRemove
        self.pickers = pickers
    }

    @FocusState private var isTextFieldFocused: Bool
    @State private var isFocusedOnEditing = false

    var body: some View {
        HStack(spacing: 8) {
            if !isFocusedOnEditing {
                pickers().lineLimit(1)
            }
            TextField("Value", text: $textFieldValue)
                .onSubmit { text = textFieldValue }
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
#if os(iOS)
                .autocapitalization(.none)
#else
                .frame(minWidth: 90)
#endif
                .onChange(of: isTextFieldFocused) { isTextFieldFocused in
#if os(iOS)
                    withAnimation { isFocusedOnEditing = isTextFieldFocused }
#endif
                }
            if !isFocusedOnEditing {
                if let onRemove = self.onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            } else {
                Button("Done") {
                    text = textFieldValue
                    isTextFieldFocused = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
        }
#if os(iOS)
        .padding(EdgeInsets(top: 2, leading: -6, bottom: 2, trailing: -8))
#endif
    }
}

#endif
