// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS) || os(watchOS)

// MARK: - View

struct NetworkInspectorTransferInfoView: View {
    @Environment(\.colorScheme) var colorScheme

    let viewModel: NetworkInspectorTransferInfoViewModel

#if os(watchOS)
    var body: some View {
        VStack {
            HStack {
                Spacer()
                bytesSent
                Spacer()
            }

            Divider()
                .padding([.top, .bottom], 12)

            HStack {
                Spacer()
                bytesReceived
                Spacer()
            }
        }
    }
#else
    var body: some View {
        HStack {
            Spacer()
            bytesSent
            Spacer()

            Divider()

            Spacer()
            bytesReceived
            Spacer()
        }
    }
#endif

    private var bytesSent: some View {
        makeView(
            title: "Bytes Sent",
            imageName: "icloud.and.arrow.up",
            total: viewModel.totalBytesSent,
            headers: viewModel.headersBytesSent,
            body: viewModel.bodyBytesSent
        )
    }

    private var bytesReceived: some View {
        makeView(
            title: "Bytes Received",
            imageName: "icloud.and.arrow.down",
            total: viewModel.totalBytesReceived,
            headers: viewModel.headersBytesReceived,
            body: viewModel.bodyBytesReceived
        )
    }

    private func makeView(title: String, imageName: String, total: String, headers: String, body: String) -> some View {
        VStack {
            Text(title)
                .font(.headline)
            HStack {
                Image(systemName: imageName)
                    .font(.system(size: 34))
                Text(total)
                    .font(.headline)
            }.padding(2)
            if viewModel.isFromCache {
                Text("(from cache)")
                    .foregroundColor(.secondary)
                    .font(.system(size: fontSize))
            } else {
                HStack(alignment: .center, spacing: 4) {
                    VStack(alignment: .trailing) {
                        Text("Headers:")
                            .foregroundColor(.secondary)
                            .font(.system(size: fontSize))
                        Text("Body:")
                            .foregroundColor(.secondary)
                            .font(.system(size: fontSize))
                    }
                    VStack(alignment: .leading) {
                        Text(headers)
                            .font(.system(size: fontSize))
                        Text(body)
                            .font(.system(size: fontSize))
                    }
                }
            }
        }
    }
}

private var fontSize: CGFloat {
#if os(iOS)
    return 15
#else
    return 12
#endif
}

// MARK: - Preview

#if DEBUG && !os(watchOS)
struct NetworkInspectorTransferInfoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkInspectorTransferInfoView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)

            NetworkInspectorTransferInfoView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
                .previewDisplayName("Dark")
                .environment(\.colorScheme, .dark)
        }
    }
}

private let mockModel = NetworkInspectorTransferInfoViewModel(
    metrics: MockDataTask.login.metrics
)!
#endif

#endif

// MARK: - ViewModel

struct NetworkInspectorTransferInfoViewModel {
    let totalBytesSent: String
    let bodyBytesSent: String
    let headersBytesSent: String

    let totalBytesReceived: String
    let bodyBytesReceived: String
    let headersBytesReceived: String

    var isFromCache: Bool

    init(empty: Bool) {
        self.totalBytesSent = "–"
        self.bodyBytesSent = "–"
        self.headersBytesSent = "–"
        self.totalBytesReceived = "–"
        self.bodyBytesReceived = "–"
        self.headersBytesReceived = "–"

        self.isFromCache = false
    }

    init?(metrics: NetworkLoggerMetrics) {
        guard let details = metrics.transactions.last?.details else { return nil }

        self.totalBytesSent = formatBytes(details.countOfRequestBodyBytesBeforeEncoding + details.countOfRequestHeaderBytesSent)
        self.bodyBytesSent = formatBytes(details.countOfRequestBodyBytesSent)
        self.headersBytesSent = formatBytes(details.countOfRequestHeaderBytesSent)

        self.totalBytesReceived = formatBytes(details.countOfResponseBodyBytesReceived + details.countOfResponseHeaderBytesReceived)
        self.bodyBytesReceived = formatBytes(details.countOfResponseBodyBytesReceived)
        self.headersBytesReceived = formatBytes(details.countOfResponseHeaderBytesReceived)

        self.isFromCache = metrics.transactions.last?.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.localCache.rawValue
    }
}

// MARK: - Private

private func formatBytes(_ count: Int64) -> String {
    guard count > 0 else {
        return "0"
    }
    return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
}
