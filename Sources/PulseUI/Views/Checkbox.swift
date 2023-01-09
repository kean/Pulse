// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct Checkbox: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
#if os(iOS)
        Button(action: { isOn.toggle() }) {
            HStack {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(isOn ? .blue : .secondary)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
#else
        Toggle(title, isOn: $isOn)
#endif
    }
}

struct CheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            Checkbox("Checkbox", isOn: .constant(true)).disabled(false)
            Checkbox("Checkbox", isOn: .constant(false)).disabled(false)
            Checkbox("Checkbox", isOn: .constant(true)).disabled(true)
            Checkbox("Checkbox", isOn: .constant(false)).disabled(true)
        }
    }
}
