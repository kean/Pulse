// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleTimestampView: View {
    let date: Date

    var body: some View {
        Text(ConsoleMessageCell.timeFormatter.string(from: date))
#if os(tvOS)
            .font(.system(size: 21))
#else
            .font(.caption)
#endif
            .monospacedDigit()
            .tracking(-0.5)
            .lineLimit(1)
            .foregroundStyle(.secondary)
    }
}

@available(iOS 15, visionOS 1, *)
struct MockBadgeView: View {
    var body: some View {
        Text("MOCK")
            .foregroundStyle(.background)
            .font(.caption2.weight(.semibold))
            .padding(EdgeInsets(top: 2, leading: 5, bottom: 1, trailing: 5))
            .background(Color.secondary.opacity(0.66))
            .clipShape(Capsule())
    }
}

struct StatusIndicatorView: View {
    let state: NetworkTaskEntity.State?

    var body: some View {
        Image(systemName: "circle.fill")
            .foregroundStyle(color)
#if os(tvOS)
            .font(.system(size: 12))
#else
            .font(.system(size: 10))
#endif
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var color: Color {
        guard let state else {
            return .secondary
        }
        switch state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }
}
