// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)

struct FilterSectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    let reset: () -> Void
    let isDefault: Bool
    var isEnabled: Binding<Bool> = .constant(true)

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title.uppercased())
            }
            .font(.body)
            Spacer()

            Button(action: reset) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 34, height: 34)
            .disabled(isDefault)
        }.buttonStyle(.plain)
    }
}

#endif
