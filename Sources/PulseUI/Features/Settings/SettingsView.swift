// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(watchOS) || os(tvOS)
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
            if #available(iOS 14.0, tvOS 14.0, *) {
                sectionStoreDetails
            }
#if os(watchOS)
            sectionTransferStore
#endif
            if !viewModel.isArchive {
                Section {
                    ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
                }
            }
            if #available(iOS 14.0, tvOS 14.0, *), viewModel.isRemoteLoggingAvailable {
                Section {
                    RemoteLoggerSettingsView(viewModel: .shared)
                }
            }
#if os(iOS)
            sectionSponsor
#endif
        }
        .backport.navigationTitle("Settings")
#if os(iOS)
        .navigationBarItems(leading: viewModel.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
#endif
#if os(tvOS)
        .frame(maxWidth: 800)
#endif
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private var sectionStoreDetails: some View {
        Section {
            NavigationLink(destination: StoreDetailsView(source: .store(viewModel.store))) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Store Info")
                }
            }
#if os(iOS)
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
#endif
        }
    }

#if os(watchOS)
    private var sectionTransferStore: some View {
        Button(action: viewModel.tranferStore) {
            Label(viewModel.fileTransferStatus.title, systemImage: "square.and.arrow.up")
        }
        .disabled(viewModel.fileTransferStatus.isButtonDisabled)
        .alert(item: $viewModel.fileTransferError) { error in
            Alert(title: Text("Transfer Failed"), message: Text(error.message), dismissButton: .cancel(Text("Ok")))
        }
    }
#endif

#if os(iOS)
    private var sectionSponsor: some View {
        Section(footer: Text("Pulse is funded by the community contributions.")) {
            Button(action: {
                if let url = URL(string: "https://github.com/sponsors/kean") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color.pink)
                    Text("Sponsor")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Image(systemName: "link")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
#endif
}

#if os(iOS)
@available(iOS 14.0, *)
private struct DocumentBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        DocumentBrowserViewController(forOpeningContentTypes: [UTType(filenameExtension: "pulse")].compactMap { $0 })
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {

    }
}
#endif

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
