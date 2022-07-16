// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorTransferInfoView: View {
    @Environment(\.colorScheme) var colorScheme

    let viewModel: NetworkInspectorTransferInfoViewModel

    var body: some View {
        HStack {
            Spacer()
            makeView(title: "Bytes Sent", imageName: "icloud.and.arrow.up", total: viewModel.totalBytesSent, headers: viewModel.headersBytesSent, body: viewModel.bodyBytesSent)
            Spacer()

            Divider()

            Spacer()
            makeView(title: "Bytes Received", imageName: "icloud.and.arrow.down", total: viewModel.totalBytesReceived, headers: viewModel.headersBytesReceived, body: viewModel.bodyBytesReceived)
            Spacer()
        }
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

private var fontSize: CGFloat {
    #if os(iOS)
    return 15
    #else
    return 12
    #endif
}

// MARK: - Preview

#if DEBUG
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

private struct Row {
    let index: Int
    let items: [KeyValueSectionViewModel]
}

// MARK: - ViewModel

struct NetworkInspectorTransferInfoViewModel {
    let totalBytesSent: String
    let bodyBytesSent: String
    let headersBytesSent: String

    let totalBytesReceived: String
    let bodyBytesReceived: String
    let headersBytesReceived: String

    init?(metrics: NetworkLoggerMetrics) {
        guard let metrics = metrics.transactions.last?.details else { return nil }

        self.totalBytesSent = formatBytes(metrics.countOfRequestBodyBytesBeforeEncoding + metrics.countOfRequestHeaderBytesSent)
        self.bodyBytesSent = formatBytes(metrics.countOfRequestBodyBytesSent)
        self.headersBytesSent = formatBytes(metrics.countOfRequestHeaderBytesSent)

        self.totalBytesReceived = formatBytes(metrics.countOfResponseBodyBytesReceived + metrics.countOfResponseHeaderBytesReceived)
        self.bodyBytesReceived = formatBytes(metrics.countOfResponseBodyBytesReceived)
        self.headersBytesReceived = formatBytes(metrics.countOfResponseHeaderBytesReceived)
    }
}

// MARK: - Private

private func formatBytes(_ count: Int64) -> String {
    guard count > 0 else {
        return "0"
    }
    return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
}
