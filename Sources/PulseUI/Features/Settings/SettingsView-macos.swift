// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Pulse
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var store: LoggerStore { viewModel.store }

    @State private var isPresentingShareStoreView = false
    @State private var isPresentingStoreDetails = false
    @State private var shareItems: ShareItems?

    public init(store: LoggerStore = .shared) {
        self.viewModel = SettingsViewModel(store: store)
    }

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            settings
        }
    }

    @ViewBuilder
    private var settings: some View {
        ConsoleSection(isDividerHidden: true, header: { SectionHeaderView(title: "Share") }) {
            HStack {
                Button(action: { isPresentingShareStoreView = true }) {
                    Label("Share Store", systemImage: "square.and.arrow.up")
                }
                .popover(isPresented: $isPresentingShareStoreView) {
                    ShareStoreView(store: viewModel.store, isPresented: $isPresentingShareStoreView) { item in
                        isPresentingShareStoreView = false
                        DispatchQueue.main.async {
                            shareItems = item
                        }
                    }
                }
                .popover(item: $shareItems) { item in
                    ShareView(item)
                        .fixedSize()
                }
                Spacer()
            }
        }
        ConsoleSection(header: { SectionHeaderView(title: "Open Store") }) {
            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.storeURL])
                }
                Spacer()
            }
            HStack {
                Button("Open in Pulse Pro") {
                    NSWorkspace.shared.open(store.storeURL)
                }
                Spacer()
            }
        }
        if !viewModel.isArchive {
            ConsoleSection(header: { SectionHeaderView(title: "Manage Messages") }) {
                Button {
                    viewModel.buttonRemoveAllMessagesTapped()
                } label: {
                    Label("Remove Logs", systemImage: "trash")
                }
            }
        }
        ConsoleSection(header: { SectionHeaderView(title: "Remote Logging") }) {
            if viewModel.isRemoteLoggingAvailable {
                RemoteLoggerSettingsView(viewModel: .shared)
            } else {
                Text("Not available")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConsoleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel(store: .shared))
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
