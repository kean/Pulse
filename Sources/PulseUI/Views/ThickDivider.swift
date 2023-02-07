// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct ThinkDivider: View {
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
