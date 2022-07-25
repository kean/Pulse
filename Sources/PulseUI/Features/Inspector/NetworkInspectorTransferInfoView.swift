// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View

struct NetworkInspectorTransferInfoView: View {
    let viewModel: NetworkInspectorTransferInfoViewModel

#if os(watchOS)
    var body: some View {
        HStack(alignment: .center) {
            if viewModel.isUpload {
                bytesSent
            } else {
                bytesReceived
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
#if os(iOS) || os(tvOS) || os(macOS)
        .padding(.top, 12).padding(.bottom, 20)
#endif
    }
#endif

    private var bytesSent: some View {
        makeView(
            title: "Sent",
            imageName: "arrow.up.circle",
            total: viewModel.totalBytesSent,
            headers: viewModel.headersBytesSent,
            body: viewModel.bodyBytesSent
        )
    }

    private var bytesReceived: some View {
        makeView(
            title: "Received",
            imageName: "arrow.down.circle",
            total: viewModel.totalBytesReceived,
            headers: viewModel.headersBytesReceived,
            body: viewModel.bodyBytesReceived
        )
    }

    private func makeView(title: String, imageName: String, total: String, headers: String, body: String) -> some View {
        VStack(alignment: .center) {
            HStack(alignment: .center, spacing: spacing) {
                Image(systemName: imageName)
                    .font(.largeTitle)
                Text(title + "\n" + total)
                    .font(.headline)
                    .fixedSize()
            }.padding(2)
            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .trailing) {
                    Text("Headers:")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    Text("Body:")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                VStack(alignment: .leading) {
                    Text(headers)
                        .font(.footnote)
                    Text(body)
                        .font(.footnote)
                }
            }
        }
    }
}

#if os(tvOS)
private let spacing: CGFloat = 20
#else
private let spacing: CGFloat? = nil
#endif

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
    metrics: MockDataTask.login.metrics, taskType: .dataTask
)!
#endif

// MARK: - ViewModel

struct NetworkInspectorTransferInfoViewModel {
    let totalBytesSent: String
    let bodyBytesSent: String
    let headersBytesSent: String

    let totalBytesReceived: String
    let bodyBytesReceived: String
    let headersBytesReceived: String

    let isUpload: Bool

    init(empty: Bool) {
        self.totalBytesSent = "–"
        self.bodyBytesSent = "–"
        self.headersBytesSent = "–"
        self.totalBytesReceived = "–"
        self.bodyBytesReceived = "–"
        self.headersBytesReceived = "–"
        self.isUpload = false
    }

    init?(metrics: NetworkLoggerMetrics, taskType: NetworkLoggerTaskType) {
        guard let details = metrics.transactions.last?.details else { return nil }

        self.totalBytesSent = formatBytes(details.countOfRequestBodyBytesBeforeEncoding + details.countOfRequestHeaderBytesSent)
        self.bodyBytesSent = formatBytes(details.countOfRequestBodyBytesSent)
        self.headersBytesSent = formatBytes(details.countOfRequestHeaderBytesSent)

        self.totalBytesReceived = formatBytes(details.countOfResponseBodyBytesReceived + details.countOfResponseHeaderBytesReceived)
        self.bodyBytesReceived = formatBytes(details.countOfResponseBodyBytesReceived)
        self.headersBytesReceived = formatBytes(details.countOfResponseHeaderBytesReceived)

        self.isUpload = taskType == .uploadTask
    }
}

private func formatBytes(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: max(0, count), countStyle: .file)
}
