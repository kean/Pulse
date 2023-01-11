// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

// MARK: - View

struct SpinnerView: View {
    @ObservedObject var viewModel: ProgressViewModel

    var body: some View {
        VStack {
            ProgressView()
            if let details = viewModel.details {
                Text(details)
                    .padding(.top, 6)
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
            .previewLayout(.fixed(width: 300, height: 300))
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

    init(task: NetworkTaskEntity) {
        self.title = ProgressViewModel.title(for: task)
        observer1 = task.publisher(for: \.progress, options: [.initial, .new]).sink { [weak self] change in
            if let progress = task.progress {
                self?.register(for: progress)
            }
        }
    }

    static func title(for task: NetworkTaskEntity) -> String {
        switch task.type ?? .dataTask {
        case .downloadTask: return "Downloading"
        case .uploadTask: return "Uploading"
        default: return "Pending"
        }
    }

    private func register(for progress: NetworkTaskProgressEntity) {
        self.refresh(with: progress)
        observer2 = progress.objectWillChange.sink { [self] in
            self.refresh(with: progress)
        }
    }

    private func refresh(with progress: NetworkTaskProgressEntity) {
        let completed = progress.completedUnitCount
        let total = progress.totalUnitCount

        if completed > 0 || total > 0 {
            let lhs = ByteCountFormatter.string(fromByteCount: max(0, completed))
            let rhs = ByteCountFormatter.string(fromByteCount: total)
            self.details = total > 0 ? "\(lhs) / \(rhs)" : lhs
        }
    }
}
