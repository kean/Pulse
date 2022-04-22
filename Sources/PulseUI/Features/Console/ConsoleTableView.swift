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

    func makeUIViewController(context: Context) -> ConsoleTableViewController {
        let vc = ConsoleTableViewController(viewModel: viewModel)
        vc.setHeaderView(header())
        vc.onSelected = onSelected
        return vc
    }

    func updateUIViewController(_ uiViewController: ConsoleTableViewController, context: Context) {
        // Do nothing
    }
}

@available(iOS 13.0, *)
final class ConsoleTableViewController: UITableViewController {
    private let viewModel: ConsoleTableViewModel
    private var entities: [NSManagedObject] = []
    private var cancellables: [AnyCancellable] = []

    var onSelected: ((NSManagedObject) -> Void)?

    init(viewModel: ConsoleTableViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
        self.createView()
        self.bind(viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        tableView.register(ConsoleMessageTableCell.self, forCellReuseIdentifier: "ConsoleMessageTableCell")
    }

    private func bind(_ viewModel: ConsoleTableViewModel) {
        viewModel.$entities.sink { [weak self] entities in
            self?.display(entities)
        }.store(in: &cancellables)
    }

    private func display(_ entities: [NSManagedObject]) {
        self.entities = entities
        self.tableView.reloadData()
    }

    func setHeaderView<Header: View>(_ view: Header) {
        let header = UIHostingController(rootView: view).view
        header?.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        tableView.tableHeaderView = header
    }

    // MARK: - UITableViewDelegate/DataSourece

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entity = entities[indexPath.row]

        func makeTableCell(for message: LoggerMessageEntity) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleMessageTableCell", for: indexPath) as! ConsoleMessageTableCell
            cell.display(.init(message: message, context: viewModel.context, searchCriteriaViewModel: viewModel.searchCriteriaViewModel))
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelected?(entities[indexPath.row])
    }
}

#endif
