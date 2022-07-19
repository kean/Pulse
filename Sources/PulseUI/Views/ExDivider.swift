// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(macOS)

struct ExDivider: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var color: Color {
        colorScheme == .dark ? .black : .separator
    }
    var width: CGFloat = 1
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .edgesIgnoringSafeArea(.vertical)
    }
}

#endif
