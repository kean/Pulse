// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS)

struct KeyValueGridView: View {
#if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
#endif
    let items: [KeyValueSectionViewModel]

    var body: some View {
#if os(iOS)
        let isTwoColumnEnabled = sizeClass == .regular && items.count > 1
#else
        let isTwoColumnEnabled = items.count > 1
#endif
        if isTwoColumnEnabled {
            VStack(spacing: 16) {
                let rows = items.chunked(into: 2).enumerated().map {
                    Row(index: $0, items: $1)
                }
                ForEach(rows, id: \.index) { row in
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(row.items, id: \.title) { item in
                            KeyValueSectionView(viewModel: item)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 16) {
                ForEach(items, id: \.title) {
                    KeyValueSectionView(viewModel: $0)
                }
            }
        }
    }
}

private struct Row {
    let index: Int
    let items: [KeyValueSectionViewModel]
}

#endif
