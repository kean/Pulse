// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS)
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var console: ConsoleViewModel

    @State private var isDocumentBrowserPresented = false

    public init(store: LoggerStore = .shared) {
        self.viewModel = SettingsViewModel(store: store)
        self.console = ConsoleViewModel(store: store)
    }

    init(viewModel: SettingsViewModel, console: ConsoleViewModel) {
        self.viewModel = viewModel
        self.console = console
    }

    public var body: some View {
        Form {
            if let details = viewModel.details {
                Section {
                    NavigationLink(destination: StoreDetailsView(viewModel: details)) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(Color.primary)
                            Text("Store Info")
                                .foregroundColor(Color.primary)
                        }
                    }
                }
            }

            if !viewModel.isReadonly {
                Section {
                    if #available(iOS 14.0, *) {
                        Button(action: {
                            isDocumentBrowserPresented = true
                        }) {
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(Color.primary)
                                Text("Browse Files")
                                    .foregroundColor(Color.primary)
                            }
                        }
                        .fullScreenCover(isPresented: $isDocumentBrowserPresented) {
                            DocumentBrowser()
                        }
                    }

                    ButtonRemoveAll(action: console.buttonRemoveAllMessagesTapped)
                }
                if #available(iOS 14.0, *) {
                    #warning("TODO: rewrite using SettingsViewModel")
                    if console.store === RemoteLogger.shared.store {
                        Section {
                            RemoteLoggerSettingsView(viewModel: .shared)
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Settings")
        .navigationBarItems(leading: viewModel.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
    }
}

@available(iOS 14.0, *)
private struct DocumentBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        DocumentBrowserViewController(forOpeningContentTypes: [UTType(filenameExtension: "pulse")].compactMap { $0 })
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {

    }
}

// MARK: - Settings

final class SettingsViewModel: ObservableObject {
    private let store: LoggerStore

    var onDismiss: (() -> Void)?

    init(store: LoggerStore) {
        self.store = store
    }

    var isReadonly: Bool {
        store.isReadonly
    }

    #warning("TODO: rework")
    var details: StoreDetailsViewModel? {
        nil
//        store.info.map { StoreDetailsViewModel(storeURL: store.storeURL, info: $0) }
    }
}

// MARK: - Preview

#if DEBUG
struct ConsoleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel(store: .mock), console: ConsoleViewModel(store: .mock))
    }
}
#endif
#endif

// MARK: - Helpers

struct ButtonRemoveAll: View {
    let action: () -> Void

    var body: some View {
        #if os(watchOS)
        let title = "Remove All"
        #else
        let title = "Remove Messages"
        #endif
        ButtonRemove(title: title, alert: "Are you sure you want to remove all recorded messages?", action: action)
    }
}

struct ButtonRemove: View {
    let title: String
    let alert: String
    let action: () -> Void

    var body: some View {
        let button =
            Button(action: action) {
                #if os(watchOS)
                Label(title, systemImage: "trash")
                #else
                HStack {
                    Image(systemName: "trash")
                    Text(title)
                }
                #endif
            }

        #if os(macOS)
        button
        #else
        button.foregroundColor(.red)
        #endif
    }
}
