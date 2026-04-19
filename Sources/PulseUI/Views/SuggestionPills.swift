// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct SuggestionPills<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
        }
        .scrollClipDisabled()
    }
}

struct SuggestionPill: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(EdgeInsets(top: 7, leading: 12, bottom: 9, trailing: 12))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(.secondaryLabel).opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        }
        .buttonStyle(.plain)
    }
}
