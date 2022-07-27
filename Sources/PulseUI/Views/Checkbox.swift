// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS)

struct Checkbox: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
        }.buttonStyle(.plain)
    }
}

struct CheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            HStack(spacing: 16) {
                Checkbox(isEnabled: .constant(true))
                    .disabled(false)
                Checkbox(isEnabled: .constant(false))
                    .disabled(false)
            }
            HStack(spacing: 16) {
                Checkbox(isEnabled: .constant(true))
                    .disabled(true)
                Checkbox(isEnabled: .constant(false))
                    .disabled(true)
            }
        }
    }
}
#endif
