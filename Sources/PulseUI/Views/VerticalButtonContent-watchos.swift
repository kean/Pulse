// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(watchOS)

struct VerticalButtonContent: View {
    let title: String
    let systemImageName: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImageName)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption2)
        }.frame(height: 42)
    }
}

#endif
