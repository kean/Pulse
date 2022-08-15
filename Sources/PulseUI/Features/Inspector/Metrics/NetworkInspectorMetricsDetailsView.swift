// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorMetricsDetailsView: View {
    let viewModel: NetworkMetricsDetailsViewModel

    var body: some View {
        KeyValueGridView(items: viewModel.sections)
    }
}

// MARK: - ViewModel

struct NetworkMetricsDetailsViewModel {
    let sections: [KeyValueSectionViewModel]

    init?(metrics: NetworkTransactionMetricsEntity) {
        guard metrics.fetchType != .localCache else {
            return nil
        }
        self.sections = [
            makeTransferSection(for: metrics),
            makeProtocolSection(for: metrics),
            makeMiscSection(for: metrics),
            makeSecuritySection(for: metrics)
        ].compactMap { $0 }
    }
}

private func makeTransferSection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
    let transferSize = metrics.transferSize
    return KeyValueSectionViewModel(title: "Data Transfer", color: .secondary, items: [
        ("Request Headers", formatBytes(transferSize.requestHeaderBytesSent)),
        ("Request Body", formatBytes(transferSize.requestBodyBytesBeforeEncoding)),
        ("Request Body (Encoded)", formatBytes(transferSize.requestBodyBytesSent)),
        ("Response Headers", formatBytes(transferSize.responseHeaderBytesReceived)),
        ("Response Body", formatBytes(transferSize.responseBodyBytesReceived)),
        ("Response Body (Decoded)", formatBytes(transferSize.responseBodyBytesAfterDecoding))
    ])
}

private func makeProtocolSection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
    KeyValueSectionViewModel(title: "Protocol", color: .secondary, items: [
        ("Network Protocol", metrics.networkProtocol),
        ("Remote Address", metrics.remoteAddress),
        ("Remote Port", metrics.remotePort > 0 ? String(metrics.remotePort) : nil),
        ("Local Address", metrics.localAddress),
        ("Local Port", metrics.localPort > 0 ? String(metrics.localPort) : nil)
    ])
}

private func makeSecuritySection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
    guard let suite = metrics.negotiatedTLSCipherSuite,
          let version = metrics.negotiatedTLSProtocolVersion else {
        return nil
    }
    return KeyValueSectionViewModel(title: "Security", color: .secondary, items: [
        ("Cipher Suite", suite.description),
        ("Protocol Version", version.description)
    ])
}

private func makeMiscSection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
    KeyValueSectionViewModel(title: "Characteristics", color: .secondary, items: [
        ("Cellular", metrics.isCellular.description),
        ("Expensive", metrics.isExpensive.description),
        ("Constrained", metrics.isConstrained.description),
        ("Proxy Connection", metrics.isProxyConnection.description),
        ("Reused Connection", metrics.isReusedConnection.description),
        ("Multipath", metrics.isMultipath.description)
    ])
}

// MARK: - Private

private func formatBytes(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count)
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorMetricsDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorMetricsDetailsView(viewModel: .init(
            metrics: LoggerStore.preview.entity(for: .login).transactions.first!
        )!)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

#endif
