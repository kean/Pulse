// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Charts

@available(iOS 16, tvOS 16, macOS 13, watchOS 9, visionOS 1, *)
package struct LoggerStoreSizeChart: View {
    package let info: LoggerStore.Info
    package let sizeLimit: Int64?

    package init(info: LoggerStore.Info, sizeLimit: Int64?) {
        self.info = info
        self.sizeLimit = sizeLimit
    }

    package var body: some View {
        VStack {
            HStack {
                Text("Logs")
                Spacer()
                Text(title).foregroundColor(.secondary)
            }
            chart
        }
    }

    private var title: String {
        let used = ByteCountFormatter.string(fromByteCount: info.totalStoreSize)
        let limit = sizeLimit.map(ByteCountFormatter.string)
        if let limit = limit {
#if os(watchOS)
            return "\(used) / \(limit)"
#else
            return "\(used) of \(limit) used"
#endif
        }
        return used
    }

    private var chart: some View {
        Chart(data) {
            BarMark(x: .value("Data Size", $0.bytes), stacking: .normalized)
                .foregroundStyle(by: .value("Category", $0.category))
        }
        .chartForegroundStyleScale([
            Category.messages: .blue,
            Category.responses: .green,
            Category.free: .secondaryFill
        ])
        .chartPlotStyle { $0.cornerRadius(8) }
#if os(tvOS)
        .frame(height: 100)
#elseif os(watchOS)
        .frame(height: 52)
#else
        .frame(height: 60)
#endif
    }

    private var data: [Series] {
        [Series(category: .messages, bytes: info.totalStoreSize - info.blobsSize),
         Series(category: .responses, bytes: info.blobsSize),
         sizeLimit.map { Series(category: .free, bytes: max(0, $0 - info.totalStoreSize)) }]
            .compactMap { $0 }
    }
}

@available(iOS 16, tvOS 16, macOS 13, watchOS 9.0, visionOS 1, *)
private enum Category: String, Hashable, Plottable {
    case messages = "Logs"
    case responses = "Blobs"
    case free = "Free"
}

@available(iOS 16, tvOS 16, macOS 13, watchOS 9.0, visionOS 1, *)
private struct Series: Identifiable {
    let category: Category
    let bytes: Int64
    var id: Category { category }
}

#if DEBUG
//@available(iOS 16, tvOS 16, macOS 13, watchOS 9.0, visionOS 1, *)
//struct LoggerStoreSizeChart_Previews: PreviewProvider {
//    static var previews: some View {
//        LoggerStoreSizeChart(info: try! LoggerStore.mock.info(), sizeLimit: 512 * 1024)
//            .padding()
//            .previewLayout(.sizeThatFits)
//    }
//}
#endif
