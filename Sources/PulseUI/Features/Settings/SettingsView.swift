// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(watchOS)
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

#if os(iOS)
    @State private var isDocumentBrowserPresented = false
#endif

    public init(store: LoggerStore = .shared) {
        // TODO: Fix ownership
        self.viewModel = SettingsViewModel(store: store)
    }

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            if #available(iOS 14.0, *) {
                sectionStoreDetails
            }
            ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
            if #available(iOS 14.0, *), viewModel.isRemoteLoggingAvailable {
                Section {
                    RemoteLoggerSettingsView(viewModel: .shared)
                }
            }
        }
        .backport.navigationTitle("Settings")
        .navigationBarItems(leading: viewModel.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
    }

    @available(iOS 14.0, *)
    private var sectionStoreDetails: some View {
        Section {
            NavigationLink(destination: StoreDetailsView(source: .store(viewModel.store))) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Store Info")
                }
            }
            if !viewModel.isArchive {
                Button(action: { isDocumentBrowserPresented = true }) {
                    HStack {
                        Image(systemName: "doc")
                        Text("Browse Stores")
                    }
                }
                .fullScreenCover(isPresented: $isDocumentBrowserPresented) {
                    DocumentBrowser()
                }
            }
        }
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

// MARK: - Preview

#if DEBUG
struct ConsoleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(viewModel: .init(store: .mock))
        }
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
