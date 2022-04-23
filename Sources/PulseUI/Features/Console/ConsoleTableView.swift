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
    private var entityViewModels: [NSManagedObjectID: AnyObject] = [:]
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

    // MARK: - ViewModel

    func getEntityViewModel(at indexPath: IndexPath) -> AnyObject {
        let entity = entities[indexPath.row]
        if let viewModel = entityViewModels[entity.objectID] {
            return viewModel
        }
        let viewModel: AnyObject
        switch entity {
        case let message as LoggerMessageEntity:
            if let request = message.request {
                viewModel = ConsoleNetworkRequestViewModel(request: request, context: self.viewModel.context)
            } else {
                viewModel = ConsoleMessageViewModel(message: message, context: self.viewModel.context, searchCriteriaViewModel: self.viewModel.searchCriteriaViewModel)
            }
        case let request as LoggerNetworkRequestEntity:
            viewModel = ConsoleNetworkRequestViewModel(request: request, context: self.viewModel.context)
        default:
            fatalError("Invalid entity: \(entity)")
        }
        entityViewModels[entity.objectID] = viewModel
        return viewModel
    }

    // MARK: - UITableViewDelegate/DataSourece

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch getEntityViewModel(at: indexPath) {
        case let viewModel as ConsoleMessageViewModel:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleMessageTableCell", for: indexPath) as! ConsoleMessageTableCell
            cell.display(viewModel)
            return cell
        case let viewModel as ConsoleNetworkRequestViewModel:
            let cell = UITableViewCell()
            cell.textLabel?.text = viewModel.text
            return cell
        default:
            fatalError("Invalid viewModel: \(viewModel)")
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelected?(entities[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let pinViewModel = (getEntityViewModel(at: indexPath) as? Pinnable)?.pinViewModel else {
            return nil
        }
        let actions = UISwipeActionsConfiguration(actions: [
            .makePinAction(with: pinViewModel)
        ])
        actions.performsFirstActionWithFullSwipe = true
        return actions
    }
}

#endif
