// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct SettingsView: View {
    private enum Tabs: Hashable {
        case remote
    }

    var body: some View {
        TabView {
            RemoteLoggingSettingsView()
                .tabItem {
                    Label("Remote Logging", systemImage: "network")
                }
                .tag(Tabs.remote)
        }
    }
}

struct RemoteLoggingSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var server = RemoteLoggerServer.shared
    @ObservedObject var model = RemoteLoggerViewModel.shared

    var body: some View {
        Form {
            Section(content: {
                Toggle("Remote logging", isOn: $model.isRemoteLoggingEnabled)
            }, footer: {
                Text("Listens to the apps on the local network that has Pulse framework installed and remote logging enabled")
                    .foregroundColor(.secondary)
            })

            Section {
                TextField("Port", text: settings.$port)
                    .frame(maxWidth: 200)
                TextField("Service Name", text: settings.$serviceName)
            }

            Spacer()

            Section {
                HStack {
                    RemogeLoggingStatusView()
                    Spacer()
                    Button("Apply Settings", action: server.restart)
                        .fixedSize()
                }
            }
        }
        .frame(width: 420, height: 300)
        .padding()
    }
}

private struct RemogeLoggingStatusView: View {
    @ObservedObject var server = RemoteLoggerServer.shared

    var body: some View {
        status
            .frame(maxWidth: 280)
    }

    @ViewBuilder
    private var status: some View {
        if let error = server.listenerSetupError {
            makeStatus(color: .red, text: error.localizedDescription)
        } else {
            switch server.listenerState {
            case .cancelled:
                makeStatus(color: .gray, text: "Disabled")
            case .failed(let error), .waiting(let error):
                makeStatus(color: .red, text: error.localizedDescription)
            case .setup:
                makeStatus(color: .yellow, text: "Setting Up")
            case .ready:
                makeStatus(color: .green, text: "Accepting Connections")
            @unknown default:
                makeStatus(color: .gray, text: "Disabled")
            }
        }
    }

    private func makeStatus(color: Color, text: String) -> some View {
        HStack {
            makeCircle(color: color)
            Text(text)
                .lineLimit(2)
            Spacer()
        }
    }

    private func makeCircle(color: Color) -> some View {
        Circle()
            .frame(width: 10, height: 10)
            .foregroundColor(color)
    }
}

#if DEBUG
struct Previews_SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
