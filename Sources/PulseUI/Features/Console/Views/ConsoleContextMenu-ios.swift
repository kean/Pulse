// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

struct ConsoleContextMenu: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    @ObservedObject var router: ConsoleRouter

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
        self.router = viewModel.router
    }

    var body: some View {
        Menu {
            Section {
                Button(action: { router.isShowingAsText.toggle() }) {
                    if router.isShowingAsText {
                        Label("View as List", systemImage: "list.bullet.rectangle.portrait")
                    } else {
                        Label("View as Text", systemImage: "text.quote")
                    }
                }
                if !viewModel.store.isArchive {
                    Button(action: { router.isShowingInsights = true }) {
                        Label("Insights", systemImage: "chart.pie")
                    }
                }
            }
            Section {
                Button(action: { router.isShowingStoreInfo = true }) {
                    Label("Store Info", systemImage: "info.circle")
                }
                Button(action: { router.isShowingShareStore = true }) {
                    Label("Share Store", systemImage: "square.and.arrow.up")
                }
                if !viewModel.store.isArchive {
                    Button.destructive(action: buttonRemoveAllTapped) {
                        Label("Remove Logs", systemImage: "trash")
                    }
                }
            }
            Section {
                Button(action: { router.isShowingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
            }
            Section {
                if !UserDefaults.standard.bool(forKey: "pulse-disable-support-prompts") {
                    Button(action: buttonSponsorTapped) {
                        Label("Sponsor", systemImage: "heart")
                    }
                }
                Button(action: buttonSendFeedbackTapped) {
                    Label("Report Issue", systemImage: "envelope")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func buttonRemoveAllTapped() {
        viewModel.store.removeAll()
        viewModel.index.clear()

        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
    }

    private func buttonSponsorTapped() {
        guard let url = URL(string: "https://github.com/sponsors/kean") else { return }
        UIApplication.shared.open(url)
    }

    private func buttonSendFeedbackTapped() {
        guard let url = URL(string: "https://github.com/kean/Pulse/issues") else { return }
        UIApplication.shared.open(url)
    }
}
#endif
