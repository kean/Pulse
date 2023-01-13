// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct ConsoleSearchSection<Header: View, Content: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
#if os(macOS)
        Section(content: {
            VStack(spacing: 8) {
                content()
            }
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        },header: {
            header()
                .padding(.horizontal, 24)
        })
#else
        Section(content: content, header: header)
#endif
    }
}
