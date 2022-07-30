// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

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

    init(metrics: NetworkLoggerTransactionMetrics) {
        self.sections = [
            makeTransferSection(for: metrics),
            makeProtocolSection(for: metrics),
            makeMiscSection(for: metrics),
            makeSecuritySection(for: metrics)
        ].compactMap { $0 }
    }
}

private func makeTransferSection(for metrics: NetworkLoggerTransactionMetrics) -> KeyValueSectionViewModel? {
    guard let metrics = metrics.details else { return nil }
    return KeyValueSectionViewModel(title: "Data Transfer", color: .secondary, items: [
        ("Request Body", formatBytes(metrics.countOfRequestBodyBytesBeforeEncoding)),
        ("Request Body (Encoded)", formatBytes(metrics.countOfRequestBodyBytesSent)),
        ("Request Headers", formatBytes(metrics.countOfRequestHeaderBytesSent)),
        ("Response Body", formatBytes(metrics.countOfResponseBodyBytesReceived)),
        ("Response Body (Decoded)", formatBytes(metrics.countOfResponseBodyBytesAfterDecoding)),
        ("Response Headers", formatBytes(metrics.countOfResponseHeaderBytesReceived))
    ])
}

private func makeProtocolSection(for metrics: NetworkLoggerTransactionMetrics) -> KeyValueSectionViewModel? {
    guard let details = metrics.details else { return nil }
    return KeyValueSectionViewModel(title: "Protocol", color: .secondary, items: [
        ("Network Protocol", metrics.networkProtocolName),
        ("Remote Address", details.remoteAddress),
        ("Remote Port", details.remotePort.map(String.init)),
        ("Local Address", details.localAddress),
        ("Local Port", details.localPort.map(String.init))
    ])
}

private func makeSecuritySection(for metrics: NetworkLoggerTransactionMetrics) -> KeyValueSectionViewModel? {
    guard let metrics = metrics.details else { return nil }

    guard let suite = metrics.negotiatedTLSCipherSuite.flatMap(tls_ciphersuite_t.init(rawValue:)),
          let version = metrics.negotiatedTLSProtocolVersion.flatMap(tls_protocol_version_t.init(rawValue:)) else {
        return nil
    }
    return KeyValueSectionViewModel(title: "Security", color: .secondary, items: [
        ("Cipher Suite", suite.description),
        ("Protocol Version", version.description)
    ])
}

private func makeMiscSection(for metrics: NetworkLoggerTransactionMetrics) -> KeyValueSectionViewModel? {
    let details = metrics.details
    return KeyValueSectionViewModel(title: "Characteristics", color: .secondary, items: [
        ("Cellular", details?.isCellular.description),
        ("Expensive", details?.isExpensive.description),
        ("Constrained", details?.isConstrained.description),
        ("Proxy Connection", metrics.isProxyConnection.description),
        ("Reused Connection", metrics.isReusedConnection.description),
        ("Multipath", details?.isMultipath.description)
    ])
}

// MARK: - Private

private func formatBytes(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorMetricsDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorMetricsDetailsView(viewModel: .init(
            metrics: MockTask.login.metrics.transactions.first!
        ))
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

#endif
