// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
struct TimingView: View {
    let viewModel: [TimingRowSectionViewModel]
    let width: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel, id: \.self.title) {
                TimingSectionView(viewModel: $0, width: width)
            }
        }
    }
}

@available(iOS 13.0, tvOS 14.0, *)
private struct TimingSectionView: View {
    let viewModel: TimingRowSectionViewModel
    let width: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(viewModel.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(viewModel.items, id: \.self.title) {
                    TimingRowView(viewModel: $0, width: width)
                }
            }
        }
    }
}

@available(iOS 13.0, tvOS 14.0, *)
private struct TimingRowView: View {
    let viewModel: TimingRowViewModel
    let width: CGFloat

    #if os(tvOS)
    static let rowHeight: CGFloat = 46
    static let titleWidth: CGFloat = 170
    static let valueWidth: CGFloat = 120
    #else
    static let rowHeight: CGFloat = 14
    static let titleWidth: CGFloat = 80
    static let valueWidth: CGFloat = 56
    #endif

    var body: some View {
        HStack {
            let barWidth = width - TimingRowView.titleWidth - TimingRowView.valueWidth - 10
            let start = clamp(viewModel.start)
            let length = min(1 - start, viewModel.length)

            Text(viewModel.title)
                .font(.footnote)
                .foregroundColor(Color(UXColor.secondaryLabel))
                .frame(width: TimingRowView.titleWidth, alignment: .leading)
            Spacer()
                .frame(width: 2 + barWidth * start)
            #if os(tvOS)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(viewModel.color))
                .frame(width: max(2, barWidth * length), height: 20)
            #else
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(viewModel.color))
                .frame(width: max(2, barWidth * length))
            #endif
            Spacer()
            Text(viewModel.value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(UXColor.secondaryLabel))
                .frame(width: TimingRowView.valueWidth, alignment: .trailing)
        }
        .frame(height: TimingRowView.rowHeight)
    }
}

// MARK: - ViewModel

struct TimingRowSectionViewModel {
    let title: String
    let items: [TimingRowViewModel]
}

struct TimingRowViewModel {
    let title: String
    let value: String
    let color: UXColor
    // [0, 1]
    let start: CGFloat
    // [0, 1]
    let length: CGFloat
}

// MARK: - Private

private func clamp(_ value: CGFloat) -> CGFloat {
    max(0, min(1, value))
}

// MARK: - Preview

#if DEBUG
@available(iOS 13.0, tvOS 14.0, *)
struct TimingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GeometryReader { geo in
                TimingView(viewModel: mockModel, width: geo.size.width)
                    .previewLayout(.fixed(width: 320, height: 200))
                    .previewDisplayName("Light")
                    .environment(\.colorScheme, .light)

                TimingView(viewModel: mockModel, width: geo.size.width)
                    .previewLayout(.fixed(width: 320, height: 200))
                    .previewDisplayName("Dark")
                    .background(Color(UXColor.systemBackground))
                    .environment(\.colorScheme, .dark)
            }
        }
    }
}

private let mockModel = [
    TimingRowSectionViewModel(title: "Response", items: [
        TimingRowViewModel(title: "Scheduling", value: "0.01ms", color: .systemBlue, start: 0.0, length: 0.001),
        TimingRowViewModel(title: "Waiting", value: "41.2ms", color: .systemBlue, start: 0.0, length: 0.4),
        TimingRowViewModel(title: "Download", value: "0.2ms", color: .systemRed, start: 0.4, length: 0.05)
    ]),
    TimingRowSectionViewModel(title: "Cache Lookup", items: [
        TimingRowViewModel(title: "Waiting", value: "50.2ms", color: .systemYellow, start: 0.45, length: 0.3),
        TimingRowViewModel(title: "Download", value: "–", color: .systemGreen, start: 0.75, length: 100.0)
    ])
]
#endif

#endif
