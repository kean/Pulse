// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct SelectableButton: View {
    let image: Image
    @Binding var isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        Button(action: { isSelected.toggle() }) {
            image
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(2)
                .padding(.horizontal, 2)
                .onHover { isHovering = $0 }
                .background(isSelected ? Color.blue.opacity(0.8) : (isHovering ? Color.blue.opacity(0.25) : nil))
                .cornerRadius(4)
        }.buttonStyle(.plain)
    }
}

#endif
