// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View

#if os(iOS)
@available(iOS 13.0, *)
struct StoreDetailsView: View {
    let viewModel: StoreDetailsViewModel

    var body: some View {
        Form {
            Section {
                KeyValueSectionView(viewModel: viewModel.infoSection)
                    .padding(.top, 8)
                KeyValueSectionView(viewModel: viewModel.sizeSection)
                    .padding(.top, 8)
            }
        }
        .navigationBarTitle("Store Details", displayMode: .inline)
    }
}

// MARK: - ViewModel

@available(iOS 13, *)
final class StoreDetailsViewModel {
    private let storeURL: URL
    private let info: LoggerStoreInfo

    init(storeURL: URL, info: LoggerStoreInfo) {
        self.storeURL = storeURL
        self.info = info
    }

    private var fileSize: Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path)
        return attributes?[.size] as? Int64 ?? 0
    }

    var infoSection: KeyValueSectionViewModel {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium

        let device = info.device
        return KeyValueSectionViewModel(title: "Info", color: .gray, action: nil, items: [
            ("Device", "\(device.name) (\(device.systemName) \(device.systemVersion))"),
            info.appInfo.map { ("App", "\($0.name ?? "–") \($0.version ?? "–") (\($0.build ?? "–"))") },
            ("Created", formatter.string(from: info.createdDate)),
            ("Modified", formatter.string(from: info.modifiedDate)),
            ("Archived", formatter.string(from: info.archivedDate))
        ].compactMap { $0 })
    }

    var sizeSection: KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Size", color: .gray, action: nil, items: [
            ("Archive Size", ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file) ),
            ("Messages", info.messageCount.description),
            ("Network Requests", info.requestCount.description),
            ("Blobs Size", ByteCountFormatter.string(fromByteCount: info.blobsSize, countStyle: .file)),
            ("Messages Size", ByteCountFormatter.string(fromByteCount: info.databaseSize, countStyle: .file))
        ])
    }
}
#endif
