// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkRequestStatusSectionView: View {
    let viewModel: NetworkRequestStatusSectionViewModel

    var body: some View {
        NetworkRequestStatusCell(viewModel: viewModel.status)
        if let description = viewModel.errorDescription {
            NavigationLink(destination: destinaitionError) {
                Text(description)
                    .lineLimit(4)
                    .font(.callout)
            }
        }
        NetworkRequestInfoCell(viewModel: viewModel.requestViewModel)
    }

    @ViewBuilder
    private var destinaitionError: some View {
        NetworkDetailsView(title: "Error") { viewModel.errorDetailsViewModel }
    }
}

final class NetworkRequestStatusSectionViewModel {
    let status: NetworkRequestStatusCellModel
    let errorDescription: String?
    let requestViewModel: NetworkRequestInfoCellViewModel
    let errorDetailsViewModel: KeyValueSectionViewModel?

    init(task: NetworkTaskEntity) {
        self.status = NetworkRequestStatusCellModel(task: task)
        self.errorDescription = task.state == .failure ? task.errorDebugDescription : nil
        self.requestViewModel = NetworkRequestInfoCellViewModel(task: task)
        self.errorDetailsViewModel = KeyValueSectionViewModel.makeErrorDetails(for: task)
    }
}

#if DEBUG
struct NetworkRequestStatusSectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(MockTask.allEntities, id: \.objectID) { task in
                    Section {
                        NetworkRequestStatusSectionView(viewModel: .init(task: task))
                    }
                }
            }
#if os(macOS)
            .frame(width: 260)
#endif
        }
    }
}
#endif
