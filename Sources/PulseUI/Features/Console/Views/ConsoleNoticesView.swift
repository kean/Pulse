// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData
import Combine

#warning("add copy shortcut")

struct ConsoleNoticesView: View {
    @StateObject private var viewModel = ConsoleNoticesViewModel()
    @EnvironmentObject private var consoleViewModel: ConsoleViewModel
    @State private var selection: ConsoleSelectedItem?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(viewModel.items, content: makeCell)
            }
            .listStyle(.inset)
            .backport.hideListContentBackground()

            toolbar
        }
        .onChange(of: selection) {
            consoleViewModel.router.selection = $0
        }
        .onAppear { viewModel.bind(consoleViewModel) }
        .onDisappear { viewModel.reset() }
    }

    private func makeCell(for item: ConsoleNoticeItem) -> some View {
        HStack(alignment: .top) {
            Image(systemName: item.imageName)
                .foregroundColor(item.tintColor)
            (Text(item.text) + Text(item.details.map { " \($0)" } ?? "").foregroundColor(.secondary))
                .lineLimit(3)
        }
        .help(item.help)
        .contextMenu {
            Button("Copy") { UXPasteboard.general.string = item.help }
        }
        .tag(ConsoleSelectedItem.entity(item.id))
    }

    private var toolbar: some View {
        HStack {
            SearchBar(title: "Filter", imageName: "line.3.horizontal.decrease.circle", text: $viewModel.filterTerm)
                .frame(maxWidth: 200)
            Spacer()
            SelectableButton(image: Image(systemName: "xmark.circle"), isSelected: $viewModel.isOnlyErrors)
        }
        .padding(8)
    }
}

private final class ConsoleNoticesViewModel: ObservableObject, ConsoleDataSourceDelegate {
    private var allItems: [ConsoleNoticeItem] = []
    @Published private(set) var items: [ConsoleNoticeItem] = []
    @Published var filterTerm = ""
    @Published var isOnlyErrors = false

    private weak var consoleViewModel: ConsoleViewModel?
    private var mode: ConsoleMode = .all
    private var dataSource: ConsoleDataSource?
    private var cancellables: [AnyCancellable] = []
    private var modeObserver: AnyCancellable?

    init() {
        $filterTerm.dropFirst().sink { [weak self] in
            self?.filter(with: $0)
        }.store(in: &cancellables)

        $isOnlyErrors.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.rebind()
        }.store(in: &cancellables)
    }

    func bind(_ viewModel: ConsoleViewModel) {
        self.consoleViewModel = viewModel

        dataSource = ConsoleDataSource(store: viewModel.store, mode: .all)
        updateBasePredicate(isOnlyErrors: isOnlyErrors)
        dataSource?.delegate = self
        dataSource?.bind(viewModel.searchCriteriaViewModel)

        modeObserver = viewModel.searchCriteriaViewModel.$mode.dropFirst().sink { [weak self] in
            self?.mode = $0
            self?.rebind()
        }
    }

    private func rebind() {
        consoleViewModel.map(bind)
    }

    func reset() {
        dataSource = nil
    }

    private func updateBasePredicate(isOnlyErrors: Bool) {
        let levels: [LoggerStore.Level] = isOnlyErrors ? [.error, .critical] : [.error, .critical, .warning]
        dataSource?.basePredicate = NSPredicate(format: "level IN %@", levels.map { $0.rawValue })
    }

    private func filter(with term: String) {
        guard term.count > 0 else {
            items = allItems
            return
        }
        items = allItems.filter {
            $0.help.contains(term)
        }
    }

    // MARK: ConsoleDataSourceDelegate

    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource) {
        allItems = preprocess(dataSource.entities).compactMap(ConsoleNoticeItem.init)
        filter(with: filterTerm)
    }

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        withAnimation {
            allItems = preprocess(dataSource.entities).compactMap(ConsoleNoticeItem.init)
            filter(with: filterTerm)
        }
    }

    private func preprocess(_ entities: [NSManagedObject]) -> [LoggerMessageEntity] {
        (entities as! [LoggerMessageEntity]).filter {
            switch mode {
            case .all: return true
            case .logs: return $0.task == nil
            case .network: return $0.task != nil
            }
        }
    }
}

private struct ConsoleNoticeItem: Identifiable {
    let id: NSManagedObjectID
    var tintColor: Color
    let imageName: String
    let text: String
    var details: String?
    let help: String

    init?(entity: LoggerMessageEntity) {
        switch entity.logLevel {
        case .error, .critical:
            self.imageName = "xmark.octagon.fill"
            self.tintColor = .red
        case .warning:
            self.imageName = "exclamationmark.triangle.fill"
            self.tintColor = .orange
        default:
            assertionFailure()
            return nil
        }
        self.id = entity.objectID
        if let task = entity.task {
            self.text = task.errorDebugDescription ?? ErrorFormatter.shortErrorDescription(for: task)
            self.details = task.url
        } else {
            self.text = entity.text
        }
        self.help = text + (details.map { " (\($0))" } ?? "")
    }
}

#if DEBUG
struct Previews_ConsoleNoticesView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleNoticesView()
            .environmentObject(ConsoleViewModel(store: .mock))
    }
}
#endif

#endif
