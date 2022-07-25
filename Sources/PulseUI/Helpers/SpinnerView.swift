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
            Text(viewModel?.title ?? "Pending...")
                .padding(.top, 6)
            if let viewModel = self.viewModel {
                Text(viewModel.details)
                    .animation(nil)
            }
        }.foregroundColor(.secondary)
    }
}

struct ProgressViewModel {
    let title: String
    var completed: Int64
    var total: Int64

    var details: String {
        let lhs = ByteCountFormatter.string(fromByteCount: completed, countStyle: .file)
        let rhs = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return "\(lhs) / \(rhs)"
    }
}
