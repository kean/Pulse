// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct RemoteClientCell: View {
    @ObservedObject var client: RemoteLoggerClient
    @Environment(\.openWindow) var openWindow

    var body: some View {
        Button(action: { openWindow(id: "RemoteClient", value: client.info) }) {
            contents
        }.buttonStyle(.plain)
    }

    private var contents: some View {
        HStack {
            Image(systemName: getIconName(client: client))
                .font(.system(size: 20))
                .foregroundColor(Color.accentColor)
                .frame(width: 30, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.deviceInfo.name + " (\(client.deviceInfo.systemName + " " + client.deviceInfo.systemVersion))")
                Text((client.appInfo.name ?? "–") + " (\(client.appInfo.bundleIdentifier ?? "–"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !client.isConnected {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .help("""
        Status: \(client.isConnected ? "Connected" : "Disconnected") \(client.isPaused ? "(Paused)" : "")
        Device: \(client.deviceInfo.name) (\(client.deviceInfo.systemName + " " + client.deviceInfo.systemVersion))
        App: \(client.appInfo.name ?? "–")
        Bundle Identifier: \(client.appInfo.bundleIdentifier ?? "–")
        Version: \(client.appInfo.version ?? "–") (\(client.appInfo.build ?? "–"))
        """)
    }
}

private func getIconName(client: RemoteLoggerClient) -> String {
    let system = client.deviceInfo.systemName.lowercased()
    let model = client.deviceInfo.model.lowercased()

    switch system {
    case "ios", "ipados":
        if model.contains("ipad") {
            return "ipad"
        } else {
            return "iphone"
        }
    case "watchos":
        return "applewatch"
    case "tvos":
        return "tv"
    case "macos":
        return "laptopcomputer"
    default:
        return "folder"
    }
}
