// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine
import AppKit

final class ConsoleTableViewModel: ObservableObject {
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?
    var diff: CollectionDifference<NSManagedObjectID>?
    @Published var entities: [NSManagedObject] = []

    init(searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?) {
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
}

/// Using this because of the following List issues:
///  - Reload performance issues
///  - NavigationLink popped when cell disappears
///  - List doesn't keep scroll position when reloaded
struct ConsoleTableView: NSViewRepresentable {
    let viewModel: ConsoleTableViewModel
    let onSelected: (NSManagedObject?) -> Void

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        private let viewModel: ConsoleTableViewModel

        private var colorPrimary = NSColor.labelColor
        private var colorSecondary = NSColor.secondaryLabelColor
        private var colorOrange = NSColor.systemOrange
        private var colorRed = Palette.red

        var entities: [NSManagedObject] = []
        var cancellables: [AnyCancellable] = []

        func color(for level: LoggerStore.Level) -> NSColor {
            switch level {
            case .trace: return colorSecondary
            case .debug, .info: return colorPrimary
            case .notice, .warning: return colorOrange
            case .error, .critical: return colorRed
            }
        }

        init(viewModel: ConsoleTableViewModel) {
            self.viewModel = viewModel
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            entities.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            30
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let cell = HostingTableCell.make(in: tableView)
            switch entities[row] {
            case let message as LoggerMessageEntity:
                if let task = message.task {
                    cell.hostingView.rootView = AnyView(ConsoleNetworkRequestView(viewModel: .init(task: task)))
                } else {
                    cell.hostingView.rootView = AnyView(ConsoleMessageView(viewModel: .init(message: message)))
                }
            case let task as NetworkTaskEntity:
                cell.hostingView.rootView = AnyView(ConsoleNetworkRequestView(viewModel: .init(task: task)))
            default:
                fatalError("Invalid entity: \(entities[row])")
            }
            cell.hostingView.invalidateIntrinsicContentSize()
            return cell
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()

        let column = NSTableColumn(identifier: .init(rawValue: "first"))
        tableView.addTableColumn(column)
        tableView.headerView = nil

        let coordinator = context.coordinator

        tableView.delegate = coordinator
        tableView.dataSource = coordinator

        tableView.target = coordinator

        tableView.style = .sourceList
        tableView.usesAutomaticRowHeights = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView

        var isFirstReload = true

        viewModel.$entities.sink { [viewModel, tableView] in
            coordinator.entities = $0
            if let diff = viewModel.diff, !isFirstReload {
                viewModel.diff = nil
                tableView.apply(diff: diff)
            } else {
                tableView.reloadData()
            }
            isFirstReload = false
        }.store(in: &context.coordinator.cancellables)

        NotificationCenter.default.publisher(for: NSTableView.selectionDidChangeNotification, object: tableView).sink { [viewModel] in
            guard let table = $0.object as? NSTableView else { return }
            if viewModel.entities.indices.contains(tableView.selectedRow) {
                self.onSelected(viewModel.entities[table.selectedRow])
            } else {
                self.onSelected(nil)
            }
        }.store(in: &context.coordinator.cancellables)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Do nothing
    }
}

final class HostingTableCell: NSTableCellView {
    let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let label = NSTextField.label()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
    }

    override func layout() {
        super.layout()

        label.sizeToFit()
        label.frame.origin = CGPoint(x: 2, y: 2)
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    static func make(in tableView: NSTableView) -> HostingTableCell {
        let id = NSUserInterfaceItemIdentifier(rawValue: "HostingTableCell")
        if let view = tableView.makeView(withIdentifier: id, owner: nil) as? HostingTableCell {
          return view
        }
        let view = HostingTableCell()
        view.identifier = id
        return view
    }
}

#endif
