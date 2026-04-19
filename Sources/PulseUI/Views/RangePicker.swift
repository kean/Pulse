// The MIT License (MIT)
//
// Copyright (c) 2020–2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

package struct RangePicker: View {
    @Binding var range: ValuesRange<String>

    package init(range: Binding<ValuesRange<String>>) {
        self._range = range
    }

    package var body: some View {
        HStack {
            textField("Min", text: $range.lowerBound)
            textField("Max", text: $range.upperBound)
        }
        .frame(width: 120)
    }

    private func textField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
#if os(iOS) || os(visionOS)
            .keyboardType(.numberPad)
#endif
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(8)
    }
}
