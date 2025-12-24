// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse

/// Displays a timeline of WebSocket frames for a given network task.
@available(iOS 16, visionOS 1, macOS 13, *)
public struct WebSocketInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity
    @Environment(\.store) private var store

    public init(task: NetworkTaskEntity) {
        self.task = task
    }

    public var body: some View {
        List {
            if task.webSocketFrames.isEmpty {
                Section {
                    Text("No frames recorded")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            } else {
                Section {
                    connectionInfoView
                }
                Section("Frames (\(task.webSocketFrames.count))") {
                    ForEach(task.orderedWebSocketFrames) { frame in
                        WebSocketFrameRow(frame: frame)
                    }
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("WebSocket Frames")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var connectionInfoView: some View {
        if let wsProtocol = task.webSocketProtocol {
            HStack {
                Text("Protocol")
                Spacer()
                Text(wsProtocol)
                    .foregroundColor(.secondary)
            }
        }
        if task.webSocketCloseCode != 0 {
            HStack {
                Text("Close Code")
                Spacer()
                Text(closeCodeDescription(for: task.webSocketCloseCode))
                    .foregroundColor(.secondary)
            }
        }
        if let reason = task.webSocketCloseReason, !reason.isEmpty {
            HStack {
                Text("Close Reason")
                Spacer()
                Text(String(data: reason, encoding: .utf8) ?? "Binary data")
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        HStack {
            Text("Total Frames")
            Spacer()
            Text("\(task.webSocketFrames.count)")
                .foregroundColor(.secondary)
        }
        HStack {
            Text("Sent")
            Spacer()
            Text("\(sentFramesCount)")
                .foregroundColor(.secondary)
        }
        HStack {
            Text("Received")
            Spacer()
            Text("\(receivedFramesCount)")
                .foregroundColor(.secondary)
        }
    }

    private var sentFramesCount: Int {
        task.webSocketFrames.filter { $0.frameDirection == .sent }.count
    }

    private var receivedFramesCount: Int {
        task.webSocketFrames.filter { $0.frameDirection == .received }.count
    }

    private func closeCodeDescription(for code: Int16) -> String {
        switch code {
        case 1000: return "1000 (Normal)"
        case 1001: return "1001 (Going Away)"
        case 1002: return "1002 (Protocol Error)"
        case 1003: return "1003 (Unsupported Data)"
        case 1005: return "1005 (No Status)"
        case 1006: return "1006 (Abnormal)"
        case 1007: return "1007 (Invalid Data)"
        case 1008: return "1008 (Policy Violation)"
        case 1009: return "1009 (Message Too Big)"
        case 1010: return "1010 (Extension Required)"
        case 1011: return "1011 (Internal Error)"
        case 1015: return "1015 (TLS Handshake)"
        default: return "\(code)"
        }
    }
}

/// A row displaying a single WebSocket frame.
@available(iOS 16, visionOS 1, macOS 13, *)
struct WebSocketFrameRow: View {
    let frame: WebSocketFrameEntity

    var body: some View {
        NavigationLink(destination: WebSocketFrameDetailView(frame: frame)) {
            HStack(spacing: 12) {
                directionIcon
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(frameTypeLabel)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text(sizeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let preview = payloadPreview {
                            Text(preview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var directionIcon: some View {
        Image(systemName: frame.frameDirection == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .foregroundColor(frame.frameDirection == .sent ? .blue : .green)
            .font(.title2)
    }

    private var frameTypeLabel: String {
        switch frame.type {
        case .text: return "Text"
        case .binary: return "Binary"
        case .ping: return "Ping"
        case .pong: return "Pong"
        }
    }

    private var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: frame.payloadSize, countStyle: .file)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: frame.createdAt)
    }

    private var payloadPreview: String? {
        guard frame.type == .text, let data = frame.payload?.data else {
            return nil
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        let trimmed = text.prefix(50)
        if trimmed.count < text.count {
            return String(trimmed) + "..."
        }
        return String(trimmed)
    }
}

/// Detailed view of a single WebSocket frame.
@available(iOS 16, visionOS 1, macOS 13, *)
struct WebSocketFrameDetailView: View {
    let frame: WebSocketFrameEntity
    @State private var shareItems: ShareItems?

    var body: some View {
        List {
            Section("Frame Info") {
                HStack {
                    Text("Direction")
                    Spacer()
                    Text(frame.frameDirection == .sent ? "Sent" : "Received")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Type")
                    Spacer()
                    Text(frameTypeLabel)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Size")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: frame.payloadSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Timestamp")
                    Spacer()
                    Text(formattedDate)
                        .foregroundColor(.secondary)
                }
            }

            if let data = frame.payload?.data, !data.isEmpty {
                Section("Payload") {
                    if frame.type == .text {
                        let text = String(data: data, encoding: .utf8) ?? "Unable to decode as UTF-8"
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Text("Binary data (\(data.count) bytes)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(frameTypeLabel + " Frame")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if let data = frame.payload?.data {
                    Button(action: { sharePayload(data) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $shareItems, content: ShareView.init)
        #endif
    }

    private var frameTypeLabel: String {
        switch frame.type {
        case .text: return "Text"
        case .binary: return "Binary"
        case .ping: return "Ping"
        case .pong: return "Pong"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: frame.createdAt)
    }

    private func sharePayload(_ data: Data) {
        if frame.type == .text, let text = String(data: data, encoding: .utf8) {
            shareItems = ShareItems([text])
        } else {
            shareItems = ShareItems([data])
        }
    }
}

#endif

