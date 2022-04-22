// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import PulseCore
import CoreData
import Combine
import UIKit

@available(iOS 13.0, *)
final class ConsoleTableViewModel {
    let context: AppContext
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?
    @Published var entities: [NSManagedObject] = []

    init(context: AppContext, searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?) {
        self.context = context
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
}

/// Using this because of the following List issues:
///  - Reload performance issues
///  - NavigationLink popped when cell disappears
///  - List doesn't keep scroll position when reloaded
@available(iOS 13.0, *)
struct ConsoleTableView<Header: View>: UIViewControllerRepresentable {
    @ViewBuilder let header: () -> Header
    let viewModel: ConsoleTableViewModel
    let onSelected: (NSManagedObject) -> Void

    final class ConsoleTableViewController: UITableViewController {
        private let viewModel: ConsoleTableViewModel
        var cancellables: [AnyCancellable] = []
        var onSelected: ((NSManagedObject) -> Void)?

        init(viewModel: ConsoleTableViewModel) {
            self.viewModel = viewModel
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func numberOfSections(in tableView: UITableView) -> Int {
            1
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            viewModel.entities.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let entity = viewModel.entities[indexPath.row]

            func makeTableCell(for message: LoggerMessageEntity) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleMessageTableCell", for: indexPath) as! ConsoleMessageTableCell
                cell.display(.init(message: message, context: viewModel.context))
                return cell
            }

            func makeTableCell(for request: LoggerNetworkRequestEntity) -> UITableViewCell {
                let cell = UITableViewCell()
                cell.textLabel?.text = request.url
                return cell
            }

            switch entity {
            case let message as LoggerMessageEntity:
                if let request = message.request {
                    return makeTableCell(for: request)
                } else {
                    return makeTableCell(for: message)
                }
            case let request as LoggerNetworkRequestEntity:
                return makeTableCell(for: request)
            default:
                fatalError("Invalid entity: \(entity)")
            }
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            onSelected?(viewModel.entities[indexPath.row])
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> UITableViewController {
        let coordinator = context.coordinator

        let tableView = UITableView()
        let header = UIHostingController(rootView: self.header()).view
        header?.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        tableView.tableHeaderView = header
        tableView.delegate = coordinator
        tableView.dataSource = coordinator

        tableView.register(ConsoleMessageTableCell.self, forCellReuseIdentifier: "ConsoleMessageTableCell")

        viewModel.$entities.sink { entities in
            tableView.reloadData()
        }.store(in: &coordinator.cancellables)

        coordinator.onSelected = onSelected

        return tableView
    }

    func updateUIView(_ uiView: UITableView, context: Context) {
        // Do nothing
    }
}

#endif
