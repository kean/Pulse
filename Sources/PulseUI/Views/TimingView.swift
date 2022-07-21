// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS)

struct TimingView: View {
    let viewModel: [TimingRowSectionViewModel]
    let width: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel) {
                TimingSectionView(viewModel: $0, width: width)
            }
        }
    }
}

private struct TimingSectionView: View {
    let viewModel: TimingRowSectionViewModel
    let width: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(viewModel.title)
                    .font(.subheadline)
                    .foregroundColor(viewModel.isHeader ? .secondary : .primary)
                Spacer()
            }.padding(.top, viewModel.isHeader ? 12 : 0)
            if viewModel.isHeader {
                Divider()
            }
            if !viewModel.items.isEmpty {
                VStack(spacing: 6) {
                    ForEach(viewModel.items) {
                        TimingRowView(viewModel: $0, width: width)
                    }
                }
            }
        }
    }
}

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

final class TimingRowSectionViewModel: Identifiable {
    let title: String
    let items: [TimingRowViewModel]
    var isHeader = false

    var id: ObjectIdentifier { ObjectIdentifier(self) }

    init(title: String, items: [TimingRowViewModel], isHeader: Bool = false) {
        self.title = title
        self.items = items
        self.isHeader = isHeader
    }
}

final class TimingRowViewModel: Identifiable {
    let title: String
    let value: String
    let color: UXColor
    // [0, 1]
    let start: CGFloat
    // [0, 1]
    let length: CGFloat

    var id: ObjectIdentifier { ObjectIdentifier(self) }

    init(title: String, value: String, color: UXColor, start: CGFloat, length: CGFloat) {
        self.title = title
        self.value = value
        self.color = color
        self.start = start
        self.length = length
    }
}

// MARK: - Private

private func clamp(_ value: CGFloat) -> CGFloat {
    max(0, min(1, value))
}

// MARK: - Preview

#if DEBUG
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
