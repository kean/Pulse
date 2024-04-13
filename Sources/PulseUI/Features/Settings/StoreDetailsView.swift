// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct StoreDetailsView: View {
    @StateObject private var viewModel = StoreDetailsViewModel()

    let source: Source

    enum Source {
        /// Loads the info when the view appears on screen.
        case store(LoggerStore)
        /// Opens the info for the given archive.
        case archive(url: URL)
        /// Displays prefetched info.
        case info(LoggerStore.Info)
    }

    var body: some View {
        StoreDetailsContentsView(viewModel: viewModel)
            .onAppear { viewModel.load(from: source) }
#if os(tvOS)
            .padding()
#else
            .inlineNavigationTitle("Store Details")
#endif
    }
}

 struct StoreDetailsContentsView: View {
     @ObservedObject var viewModel: StoreDetailsViewModel
     @Environment(\.store) var store
     var isShowingActions = true

     var body: some View {
         // important: zstack fixed infinite onAppear loop on iOS 14
         ZStack {
             if let error = viewModel.errorMessage {
                 PlaceholderView(imageName: "exclamationmark.circle", title: "Failed to load info", subtitle: error)
             } else {
                 form
             }
         }
     }

     @ViewBuilder
     private var form: some View {
         Form {
             if #available(iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, *), let info = viewModel.info {
                 LoggerStoreSizeChart(info: info, sizeLimit: viewModel.storeSizeLimit)
#if os(tvOS)
                     .padding(.vertical)
                     .focusable()
#endif
#if os(macOS)
                     .padding(12)
#endif
             }
             ForEach(viewModel.sections, id: \.title) { section in
                 ConsoleSection(header: {
#if os(macOS)
                     SectionHeaderView(title: section.title)
#else
                     Text(section.title)
#endif
                 }, content: {
                     ForEach(section.items.enumerated().map(KeyValueRow.init)) { item in
                         InfoRow(title: item.title, details: item.details)
#if os(tvOS)
                             .focusable()
#endif
                     }
                 })
             }
#if os(macOS)
             if isShowingActions {
                 ConsoleSection(header: { EmptyView() }, content: {
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
                 })
             }
#endif
         }
     }
 }

// MARK: - ViewModel

final class StoreDetailsViewModel: ObservableObject {
    @Published private(set) var storeSizeLimit: Int64?
    @Published private(set) var sections: [KeyValueSectionViewModel] = []
    @Published private(set) var info: LoggerStore.Info?
    @Published private(set) var errorMessage: String?

    func load(from source: StoreDetailsView.Source) {
        do {
            switch source {
            case .store(let store):
                loadInfo(for: store)
            case .archive(let storeURL):
                display(try LoggerStore.Info.make(storeURL: storeURL))
            case .info(let value):
                display(value)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadInfo(for store: LoggerStore) {
        do {
            let info = try store.info()
            if store === LoggerStore.shared {
                self.storeSizeLimit = store.configuration.sizeLimit
            }
            self.display(info)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func display(_ info: LoggerStore.Info) {
        self.info = info
        self.sections = [
            makeSizeSection(for: info),
            makeInfoSection(for: info)
        ]
    }

    private func makeInfoSection(for info: LoggerStore.Info) -> KeyValueSectionViewModel {
        let device = info.deviceInfo
        let app = info.appInfo
        return KeyValueSectionViewModel(title: "App Info", color: .gray, items: [
            ("App", "\(app.name ?? "–") \(app.version ?? "–") (\(app.build ?? "–"))"),
            ("Device", "\(device.name) (\(device.systemName) \(device.systemVersion))")
        ])
    }

    private func makeSizeSection(for info: LoggerStore.Info) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Statistics", color: .gray, items: [
            ("Created", dateFormatter.string(from: info.creationDate)),
            ("Messages", info.messageCount.description),
            ("Requests", info.taskCount.description),
            ("Blobs Size", ByteCountFormatter.string(fromByteCount: info.blobsSize)),
            makeDecompressedRow(for: info),
        ].compactMap { $0 })
    }

    private func makeDecompressedRow(for info: LoggerStore.Info) -> (String, String?)? {
        if info.blobsDecompressedSize == info.blobsSize {
            return nil
        }
        return ("Blobs Size Decompressed", ByteCountFormatter.string(fromByteCount: info.blobsDecompressedSize))
    }
}

private let dateFormatter = DateFormatter(dateStyle: .medium, timeStyle: .medium)

#if DEBUG
struct StoreDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        StoreDetailsView(source: .store(.mock))
            .frame(width: 280)
    }
}
#endif
