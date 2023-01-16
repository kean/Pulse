// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import Pulse
import CoreData
import Combine
import UIKit

final class ConsoleTableViewModel {
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?
    var diff: CollectionDifference<NSManagedObjectID>?
    @Published var entities: [NSManagedObject] = []

    init(searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?) {
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
}

struct ConsoleTableView<Header: View>: View {
    @ViewBuilder let header: () -> Header
    let viewModel: ConsoleTableViewModel
    let detailsViewModel: ConsoleDetailsRouterViewModel

    @State private var isDetailsLinkActive = false

    var body: some View {
        _ConsoleTableView(header: header, viewModel: viewModel, onSelected: {
            detailsViewModel.select($0)
            isDetailsLinkActive = true
        })
        .background(linkCount)
    }

    @ViewBuilder
    private var linkCount: some View {
        NavigationLink.programmatic(isActive: $isDetailsLinkActive) {
            ConsoleMessageDetailsRouter(viewModel: detailsViewModel)
        }.invisible()
    }
}

/// Using this because of the following List issues:
///  - Reload performance issues
///  - NavigationLink popped when cell disappears
///  - List doesn't keep scroll position when reloaded
private struct _ConsoleTableView<Header: View>: UIViewControllerRepresentable {
    @ViewBuilder let header: () -> Header
    let viewModel: ConsoleTableViewModel
    let onSelected: (NSManagedObject) -> Void

    func makeUIViewController(context: Context) -> ConsoleTableViewController {
        let vc = ConsoleTableViewController(viewModel: viewModel)
        vc.onSelected = onSelected
        let header = self.header()
        vc.headerView = header is EmptyView ? nil : AnyView(header)
        return vc
    }

    func updateUIViewController(_ uiViewController: ConsoleTableViewController, context: Context) {
        // Do nothing
    }
}

final class ConsoleTableViewController: UITableViewController {
    private let viewModel: ConsoleTableViewModel
    private var entities: [NSManagedObject] = []
    private var entityViewModels: [NSManagedObjectID: AnyObject] = [:]
    private var cancellables: [AnyCancellable] = []

    var onSelected: ((NSManagedObject) -> Void)?
    var headerView: AnyView?

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
        tableView.register(ConsoleBaseTableCell.self, forCellReuseIdentifier: "header")
        tableView.register(ConsoleBaseTableCell.self, forCellReuseIdentifier: "message")
        tableView.register(ConsoleBaseTableCell.self, forCellReuseIdentifier: "task")

        ConsoleSettings.shared.$lineLimit.sink { [weak self] _ in
            self?.tableView.reloadData()
        }.store(in: &cancellables)
    }

    private func bind(_ viewModel: ConsoleTableViewModel) {
        viewModel.$entities.sink { [weak self] entities in
            self?.display(entities)
        }.store(in: &cancellables)
    }

    private var isFirstDisplay = true

    private func display(_ entities: [NSManagedObject]) {
        if let diff = viewModel.diff, !isFirstDisplay {
            tableView.apply(diff: diff) {
                self.entities = entities
            }
        } else {
            self.entities = entities
            tableView.reloadData()
        }
        viewModel.diff = nil
        isFirstDisplay = false
    }

    // MARK: - ViewModel

    func getViewModel(at indexPath: IndexPath) -> AnyObject {
        if indexPath.section == 0 {
            return HeaderViewViewModel()
        }
        let entity = entities[indexPath.row]
        if let viewModel = entityViewModels[entity.objectID] {
            return viewModel
        }
        let viewModel: AnyObject
        switch entity {
        case let message as LoggerMessageEntity:
            if let task = message.task {
                viewModel = ConsoleTaskCellViewModel(task: task)
            } else {
                viewModel = ConsoleMessageCellViewModel(message: message, searchCriteriaViewModel: self.viewModel.searchCriteriaViewModel)
            }
        case let task as NetworkTaskEntity:
            viewModel = ConsoleTaskCellViewModel(task: task)
        default:
            fatalError("Invalid entity: \(entity)")
        }
        entityViewModels[entity.objectID] = viewModel
        return viewModel
    }

    // MARK: - UITableViewDelegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return headerView == nil ? 0 : 1
        default: return entities.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch getViewModel(at: indexPath) {
        case let viewModel as ConsoleMessageCellViewModel:
            let cell = tableView.dequeueReusableCell(withIdentifier: "message", for: indexPath) as! ConsoleBaseTableCell
            if #available(iOS 16.0, *) {
                cell.contentConfiguration = UIHostingConfiguration {
                    ConsoleMessageCell(viewModel: viewModel, isShowingDisclosure: true)
                        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 10))
                }
                .margins(.all, 0)
            } else {
                cell.hostingView.rootView = AnyView(ConsoleMessageCell(viewModel: viewModel, isShowingDisclosure: true))
            }
            return cell
        case let viewModel as ConsoleTaskCellViewModel:
            let cell = tableView.dequeueReusableCell(withIdentifier: "task", for: indexPath) as! ConsoleBaseTableCell
            if #available(iOS 16.0, *) {
                cell.contentConfiguration = UIHostingConfiguration {
                    ConsoleTaskCell(viewModel: viewModel, isShowingDisclosure: true)
                        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 10))
                }
                .margins(.all, 0)
            } else {
                cell.hostingView.rootView = AnyView(ConsoleTaskCell(viewModel: viewModel, isShowingDisclosure: true))
            }
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "header", for: indexPath) as! ConsoleBaseTableCell
            cell.selectionStyle = .none
            if let headerView = headerView {
                cell.hostingView.rootView = headerView
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            onSelected?(entities[indexPath.row])
        }
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let pinViewModel = (getViewModel(at: indexPath) as? Pinnable)?.pinViewModel else {
            return nil
        }
        let actions = UISwipeActionsConfiguration(actions: [
            .makePinAction(with: pinViewModel)
        ])
        actions.performsFirstActionWithFullSwipe = true
        return actions
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch getViewModel(at: indexPath) {
        case let viewModel as ConsoleMessageCellViewModel:
            let focus = UIContextualAction(style: .normal, title: "Focus") { _, _, completion in
                viewModel.focus()
                completion(true)
            }
            focus.backgroundColor = .systemGreen
            focus.image = UIImage(systemName: "eye")

            let hide = UIContextualAction(style: .normal, title: "Hide") { _, _ , completion in
                viewModel.hide()
                completion(true)
            }
            hide.backgroundColor = .systemOrange
            hide.image = UIImage(systemName: "eye.slash")

            let share = UIContextualAction(style: .normal, title: "Share") { _, _, completion in
                UIActivityViewController.show(with: viewModel.share())
                completion(true)
            }
            share.backgroundColor = .systemBlue
            share.image = UIImage(systemName: "square.and.arrow.up")

            let actions = UISwipeActionsConfiguration(actions: [share, focus, hide])
            actions.performsFirstActionWithFullSwipe = true
            return actions
        case let viewModel as ConsoleTaskCellViewModel:
            let share = UIContextualAction(style: .normal, title: "Share") { _, _ , completion  in
                UIActivityViewController.show(with: viewModel.share(as: .html))
                completion(true)
            }
            share.backgroundColor = .systemBlue
            share.image = UIImage(systemName: "square.and.arrow.up")

            let actions = UISwipeActionsConfiguration(actions: [share])
            actions.performsFirstActionWithFullSwipe = true
            return actions
        default:
            return nil
        }
    }
}

private final class HeaderViewViewModel {}

private class ConsoleBaseTableCell: UITableViewCell {
    lazy var hostingView: UIHostingController<AnyView> = {
        let controller = UIHostingController(rootView: AnyView(EmptyView()))
        contentView.addSubview(controller.view)
        controller.view.backgroundColor = .clear
        controller.view.pinToSuperview(insets: UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 10))
        return controller
    }()
}
#endif
