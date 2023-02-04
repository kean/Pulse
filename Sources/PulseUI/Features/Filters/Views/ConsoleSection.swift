// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct ConsoleSection<Header: View, Content: View>: View {
    var isDividerHidden = false
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
#if os(macOS)
        Section(content: {
            VStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        },header: {
            VStack(spacing: 0) {
                if !isDividerHidden {
                    Divider()
                }
                header()
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
            }
        })
#else
        Section(content: content, header: header)
#endif
    }
}
