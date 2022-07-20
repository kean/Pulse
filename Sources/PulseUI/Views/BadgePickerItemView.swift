// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS)
struct BadgePickerItemView: View {
    let title: String
    @Binding var isEnabled: Bool
    var textColor: Color?

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            HStack {
                Text(title)
                    .foregroundColor(textColor)
                Checkbox(isEnabled: $isEnabled)
            }
            .padding(EdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 11))
            .background(isEnabled ? Color.accentColor.opacity(0.08) : Color.clear)
            .cornerRadius(.infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct BadgePickerItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            BadgePickerItemView(title: "Test", isEnabled: .constant(true))
            BadgePickerItemView(title: "Test", isEnabled: .constant(false))
        }
    }
}
#endif
