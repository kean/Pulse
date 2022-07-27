// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS)

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
        }.padding(.bottom, 8)
    }
}

extension LargeSectionHeader where Accessory == EmptyView {
    init(title: String) {
        self.title = title
    }
}

#endif
