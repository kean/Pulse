import SwiftUI

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI

package struct SectionHeaderView: View {
    package var systemImage: String?
    package let title: String

    package init(systemImage: String? = nil, title: String) {
        self.systemImage = systemImage
        self.title = title
    }

    package var body: some View {
        HStack {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
#if os(macOS)
        .padding(.bottom, 8)
#endif
    }
}

#endif
