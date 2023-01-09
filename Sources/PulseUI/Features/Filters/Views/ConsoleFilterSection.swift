// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct ConsoleFilterSection<Header: View, Content: View>: View {
    var isExpanded: Binding<Bool>
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
#if os(macOS)
        DisclosureGroup(
            isExpanded: isExpanded,
            content: {
                VStack {
                    content()
                }
                .padding(EdgeInsets(top: ConsoleFilters.contentTopInset, leading: 12, bottom: 0, trailing: 5))
            },
            label: header
        )
#else
        Section(content: content, header: header)
#endif
    }
}
