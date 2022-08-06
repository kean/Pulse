// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

@available(iOS 14.0, tvOS 14.0, *)
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
        contents
            .onAppear { viewModel.load(from: source) }
#if os(iOS)
            .navigationBarTitle("Store Details", displayMode: .inline)
#endif
    }

    @ViewBuilder
    private var contents: some View {
        if viewModel.isLoading {
            Spinner().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let error = viewModel.errorMessage {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Failed to load info", subtitle: error)
        } else {
            form
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
#if swift(>=5.7)
            if #available(iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, *), let info = viewModel.info {
                LoggerStoreSizeChart(info: info, sizeLimit: viewModel.storeSizeLimit)
#if os(macOS)
                    .padding(.bottom, 16)
#endif
            }
#endif
            ForEach(viewModel.sections, id: \.title) { section in
                Section(header: Text(section.title)) {
                    KeyValueSectionView(viewModel: section)
                        .hiddenTitle()
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - ViewModel

@available(iOS 14.0, tvOS 14.0, *)
final class StoreDetailsViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var storeSizeLimit: Int64?
    @Published private(set) var sections: [KeyValueSectionViewModel] = []
    @Published private(set) var info: LoggerStore.Info?
    @Published private(set) var errorMessage: String?

    func load(from source: StoreDetailsView.Source) {
        isLoading = true

        do {
            switch source {
            case .store(let store):
                DispatchQueue.global().async {
                    self.loadInfo(for: store)
                }
            case .archive(let storeURL):
                display(try LoggerStore.Info.make(storeURL: storeURL))
            case .info(let value):
                display(value)
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadInfo(for store: LoggerStore) {
        do {
            let info = try store.info()
            DispatchQueue.main.async {
                if store === LoggerStore.shared {
                    self.storeSizeLimit = store.configuration.sizeLimit
                }
                self.display(info)
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func display(_ info: LoggerStore.Info) {
        isLoading = false
        self.info = info
        self.sections = [
            makeSizeSection(for: info),
            makeInfoSection(for: info)
        ]
    }

    private func makeInfoSection(for info: LoggerStore.Info) -> KeyValueSectionViewModel {
        let device = info.deviceInfo
        let app = info.appInfo
        return KeyValueSectionViewModel(title: "App Info", color: .gray, action: nil, items: [
            ("App", "\(app.name ?? "–") \(app.version ?? "–") (\(app.build ?? "–"))"),
            ("Device", "\(device.name) (\(device.systemName) \(device.systemVersion))")
        ])
    }

    private func makeSizeSection(for info: LoggerStore.Info) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Statistics", color: .gray, action: nil, items: [
            ("Created", dateFormatter.string(from: info.creationDate)),
            ("Total Size", ByteCountFormatter.string(fromByteCount: info.totalStoreSize) ),
            ("Blobs Size", makeBlobsSizeText(for: info)),
            ("Messages", info.messageCount.description),
            ("Requests", info.requestCount.description)
        ])
    }

    private func makeBlobsSizeText(for info: LoggerStore.Info) -> String {
        let size = ByteCountFormatter.string(fromByteCount: info.blobsSize)
        let compressed = ByteCountFormatter.string(fromByteCount: info.blobsDecompressedSize)
        if info.blobsDecompressedSize == info.blobsSize {
            return size
        }
        return "\(compressed) (\(size) decompressed)"
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
}()

#if DEBUG
@available(iOS 14.0, tvOS 14.0, *)
struct StoreDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        StoreDetailsView(source: .store(.mock))
    }
}
#endif
