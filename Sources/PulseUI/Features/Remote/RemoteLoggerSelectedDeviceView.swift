// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Network
import Pulse

@available(iOS 15, *)
struct RemoteLoggerSelectedDeviceView: View {
    @ObservedObject var logger: RemoteLogger = .shared

    let name: String
    let server: RemoteLoggerServerViewModel?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                makeStatusView(for: logger.connectionState)
            }
            Spacer()
            if (server?.server.isProtected ?? false) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.separator)
            }
#if !os(watchOS) && !os(tvOS)
            Menu(content: {
                Button("Forget this Device", role: .destructive) {
                    logger.forgetServer(named: name)
                }
            }, label: {
                Image(systemName: "ellipsis.circle")
            })
#if os(macOS)
            .menuStyle(.borderlessButton)
            .fixedSize()
#endif
#else
            Button(role: .destructive, action: {
                logger.forgetServer(named: name)
            }, label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }).buttonStyle(.plain)
#endif
        }
    }

    private func makeStatusView(for state: RemoteLogger.ConnectionState) -> some View {
        HStack(spacing: 8) {
            Circle()
                .frame(width: circleSize, height: circleSize)
                .foregroundColor(statusColor)
            Text(statusTitle)
                .lineLimit(1)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch logger.connectionState {
        case .connected: return Color.green
        case .connecting: return Color.yellow
        case .disconnected: return Color.gray
        }
    }

    private var statusTitle: String {
        switch logger.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        }
    }
}

#if os(tvOS)
private let circleSize: CGFloat = 16
#else
private let circleSize: CGFloat = 8
#endif
