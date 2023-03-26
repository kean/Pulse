// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Cocoa
import Pulse
import PulseUI
import SwiftUI
import Combine

struct PulseDocumentViewer: View {
    @StateObject private var viewModel = PulseDocumentViewModel()

    var body: some View {
        contents
            .onOpenURL(perform: viewModel.open)
    }

    @ViewBuilder
    private var contents: some View {
        if let store = viewModel.selectedStore {
            ConsoleView(store: store)
        } else if let alert = viewModel.alert {
            PlaceholderView(imageName: "exclamationmark.circle.fill", title: alert.title, subtitle: alert.message)
        } else {
            PlaceholderView(imageName: "exclamationmark.circle.fill", title: "Failed to open store", subtitle: nil)
        }
    }
}

final class PulseDocumentViewModel: ObservableObject {
    @Published var selectedStore: LoggerStore?
    @Published var alert: AlertViewModel?

    init() {}

    func open(url: URL) {
        do {
            self.selectedStore = try LoggerStore(storeURL: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            alert = AlertViewModel(title: "Failed to open Pulse document", message: error.localizedDescription)
        }
    }
}
