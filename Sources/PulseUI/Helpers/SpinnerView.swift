// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

// MARK: - View

struct SpinnerView: View {
    @ObservedObject var viewModel: ProgressViewModel

    var body: some View {
        VStack {
            Spinner()
            Text(viewModel.title + "...")
                .padding(.top, 6)
            if let details = viewModel.details {
                Text(details)
                    .animation(nil)
            }
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

#if DEBUG
struct SpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        SpinnerView(viewModel: .init(title: "Pending", details: "2.5 MB / 6.0 MB"))
            .frame(width: 320, height: 320, alignment: .center)
    }
}
#endif

// MARK: - ViewModel

final class ProgressViewModel: ObservableObject {
    let title: String
    @Published private(set) var details: String?

    private var observer1: AnyCancellable?
    private var observer2: AnyCancellable?

    init(title: String, details: String?) {
        self.title = title
        self.details = details
    }

    init(request: LoggerNetworkRequestEntity) {
        switch request.taskType ?? .dataTask {
        case .downloadTask: self.title = "Downloading"
        case .uploadTask: self.title = "Uploading"
        default: self.title = "Pending"
        }

        observer1 = request.publisher(for: \.progress, options: [.initial, .new]).sink { [weak self] change in
            if let progress = request.progress {
                self?.register(for: progress)
            }
        }
    }

    private func register(for progress: LoggerNetworkRequestProgressEntity) {
        self.refresh(with: progress)
        observer2 = progress.objectWillChange.sink { [self] in
            self.refresh(with: progress)
        }
    }

    private func refresh(with progress: LoggerNetworkRequestProgressEntity) {
        let completed = progress.completedUnitCount
        let total = progress.totalUnitCount

        if completed > 0 || total > 0 {
            let lhs = ByteCountFormatter.string(fromByteCount: max(0, completed), countStyle: .file)
            let rhs = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            self.details = total > 0 ? "\(lhs) / \(rhs)" : lhs
        }
    }
}