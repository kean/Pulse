// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Pulse

struct SettingsView: View {
    @State private var isPresentingShareStoreView = false
    @State private var shareItems: ShareItems?

    @Environment(\.store) private var store

    var body: some View {
        List {
            if store === RemoteLogger.shared.store {
                RemoteLoggerSettingsView(viewModel: .shared)
            } else {
                Text("Not available")
                    .foregroundColor(.secondary)
            }
            Section(header: Text("Store")) {
                if #available(macOS 13, *), let info = try? store.info() {
                    LoggerStoreSizeChart(info: info, sizeLimit: store.configuration.sizeLimit)
                }
            }
            Section {
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.storeURL])
                    }
                    if !(store.options.contains(.readonly)) {
                        Button("Remove Logs") {
                            store.removeAll()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UserSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
#endif

#if os(iOS) || os(macOS)

import SwiftUI

struct SectionHeaderView: View {
    var systemImage: String?
    let title: String

    var body: some View {
        HStack {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
#if os(macOS)
        .padding(.bottom, 8)
#endif
    }
}

#endif
