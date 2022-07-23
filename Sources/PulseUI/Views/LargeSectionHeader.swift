// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct LargeSectionHeader<Accessory: View>: View {
    let title: String
    var accessory: (() -> Accessory)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                Text(title)
                    .bold()
                    .font(.title)
                    .padding(.top, 16)
                Spacer()
                accessory?()
            }
            Divider()
        }
#if !os(watchOS)
        .padding(.bottom, 8)
#endif
    }
}

extension LargeSectionHeader where Accessory == EmptyView {
    init(title: String) {
        self.title = title
    }
}
