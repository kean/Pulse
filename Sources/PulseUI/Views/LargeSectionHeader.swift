// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct LargeSectionHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .bold()
                    .font(.title)
                    .padding(.top, 16)
                Spacer()
            }
            Divider()
        }
#if !os(watchOS)
        .padding(.bottom, 8)
#endif
    }
}
