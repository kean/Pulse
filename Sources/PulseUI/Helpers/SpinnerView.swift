// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

struct SpinnerView: View {
    let viewModel: ProgressViewModel?

    var body: some View {
        VStack {
            Spinner()
            Text((viewModel?.title ?? "Pending") + "...")
                .padding(.top, 6)
            if let details = self.viewModel?.details {
                Text(details)
                    .animation(nil)
            }
        }.foregroundColor(.secondary)
    }
}

struct ProgressViewModel {
    let title: String
    var completed: Int64
    var total: Int64

    init(title: String, completed: Int64, total: Int64) {
        self.title = title
        self.completed = completed
        self.total = total
    }

    init?(request: LoggerNetworkRequestEntity) {
        guard request.state == .pending else {
            return nil
        }
        switch request.taskType ?? .dataTask {
        case .downloadTask: self.title = "Downloading"
        case .uploadTask: self.title = "Uploading"
        default: self.title = "Pending"
        }
        self.completed = request.completedUnitCount
        self.total = request.totalUnitCount
    }

    var details: String? {
        guard completed > 0 || total > 0 else {
            return nil
        }
        let lhs = ByteCountFormatter.string(fromByteCount: max(0, completed), countStyle: .file)
        let rhs = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return total > 0 ? "\(lhs) / \(rhs)" : lhs
    }
}
