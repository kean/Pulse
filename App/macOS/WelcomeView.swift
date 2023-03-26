// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    private let recentDocuments = getRecentDocuments()

    @ObservedObject var remoteLoggerViewModel: RemoteLoggerViewModel

    var body: some View {
        HSplitView {
            welcomeView
            sidebar
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Image("512")
                .resizable()
                .frame(width: 256, height: 256)
            Text("Welcome to Pulse")
                .lineLimit(1)
                .font(.system(size: 34, weight: .regular))
            Spacer().frame(height: 10)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")")
                .lineLimit(1)
                .foregroundColor(.secondary)
            Spacer().frame(height: 46)
            quickActionsView
        }
        .padding()
        .padding(.vertical, 32)
        .frame(width: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .layoutPriority(1)
    }

    @ViewBuilder
    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickActionView(title: "Open Document", details: "View .pulse document with logs", image: "doc", action: openDocument)
        }
    }

    private var sidebar: some View {
        List {
            recentDocumentsSection
            remoteDevicesSection
        }
        .frame(minWidth: 320, idealWidth: 320)
        .listStyle(.sidebar)
    }

    private var recentDocumentsSection: some View {
        Section(header: Text("Recently Open")) {
            if recentDocuments.isEmpty {
                Text("No Recent Documents")
                    .foregroundColor(.secondary)
            } else {
                ForEach(recentDocuments, id: \.self, content: DocumentCell.init)
            }
        }
    }

    private var remoteDevicesSection: some View {
        Section(header: Text("Devices")) {
            if remoteLoggerViewModel.clients.isEmpty {
                Text("No Connected Devices")
                    .foregroundColor(.secondary)
            } else {
                ForEach(remoteLoggerViewModel.clients) {
                    RemoteClientCell(client: $0)
                }
            }
        }
    }
}

private struct QuickActionView: View {
    let title: String
    let details: String
    let image: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: image)
                        .font(.system(size: 24))
                        .foregroundColor(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .lineLimit(1)
                            .font(.headline)
                        Text(details)
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private func getRecentDocuments() -> [URL] {
    Array(NSDocumentController.shared.recentDocumentURLs.prefix(5))
}

func openDocument() {
    let dialog = NSOpenPanel()

    dialog.title = "Select a Pulse document (has .pulse extension)"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = false
    dialog.canChooseDirectories = false
    dialog.canCreateDirectories = false
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = true
    dialog.allowedContentTypes = [UTType("com.github.kean.pulse-store")].compactMap { $0 }

    guard dialog.runModal() == NSApplication.ModalResponse.OK else {
        return // User cancelled the action
    }

    if let selectedUrl = dialog.url {
        NSWorkspace.shared.open(selectedUrl)
    }
}

#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(remoteLoggerViewModel: .shared)
    }
}
#endif
