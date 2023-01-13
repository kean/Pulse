// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct Checkbox<Label: View>: View {
    @Binding var isOn: Bool
    let label: () -> Label

    var body: some View {
#if os(iOS)
        Button(action: { isOn.toggle() }) {
            HStack {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(isOn ? .blue : .secondary)
                label()
                Spacer()
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
#else
        Toggle(isOn: $isOn, label: label)
#endif
    }
}

extension Checkbox where Label == Text {
    init(_ title: String, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
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
