import SwiftUI

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI

struct SectionHeaderView: View {
    var systemImage: String?
    let title: String

    var body: some View {
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
