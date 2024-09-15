// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

package struct ConsoleSection<Header: View, Content: View>: View {
    package var isDividerHidden = false
    @ViewBuilder package var header: () -> Header
    @ViewBuilder package var content: () -> Content

    package init(
        isDividerHidden: Bool = false,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isDividerHidden = isDividerHidden
        self.header = header
        self.content = content
    }

    package var body: some View {
#if os(macOS)
        Section(content: {
            VStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }, header: {
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
