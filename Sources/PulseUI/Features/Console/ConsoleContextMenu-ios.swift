// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

import UniformTypeIdentifiers

@available(iOS 14, *)
struct ConsoleContextMenu: View {
    private let store: LoggerStore
    private let isShowingAsText: Binding<Bool>?

    @State private var isShowingSettings = false
    @State private var isShowingStoreInfo = false
    @State private var isDocumentBrowserPresented = false

    init(store: LoggerStore, isShowingAsText: Binding<Bool>? = nil) {
        self.store = store
        self.isShowingAsText = isShowingAsText
    }

    var body: some View {
        Menu {
            if let isShowingAsText = isShowingAsText {
                Section {
                    Button(action: { isShowingAsText.wrappedValue.toggle() }) {
                        if isShowingAsText.wrappedValue {
                            Label("View as List", systemImage: "list.bullet.rectangle.portrait")
                        } else {
                            Label("View as Text", systemImage: "text.quote")
                        }
                    }
                }
            }
            Section {
                Button(action: { isShowingStoreInfo = true }) {
                    Label("Store Info", systemImage: "info.circle")
                }
                if !store.isArchive {
                    Button(action: { isDocumentBrowserPresented = true }) {
                        Label("Browse Logs", systemImage: "folder")
                    }
                }
                Button(action: { isShowingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
            }
            if !store.isArchive {
                Section {
                    if #available(iOS 15.0, *) {
                        Button(role: .destructive, action: buttonRemoveAllTapped) {
                            Label("Remove Logs", systemImage: "trash")
                        }
                    } else {
                        Button(action: buttonRemoveAllTapped) {
                            Label("Remove Logs", systemImage: "trash")
                        }
                    }
                }
            }
            Section {
                if !UserDefaults.standard.bool(forKey: "pulse-disable-support-prompts") {
                    Text("Pulse is funded by the community contributions")
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
        .sheet(isPresented: $isShowingSettings) {
            NavigationView {
                SettingsView(store: store)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button(action: { isShowingSettings = false }) {
                        Text("Done")
                    })
            }
        }
        .sheet(isPresented: $isShowingStoreInfo) {
            NavigationView {
                StoreDetailsView(source: .store(store))
                    .navigationBarItems(trailing: Button(action: { isShowingStoreInfo = false }) {
                        Text("Done")
                    })
            }
        }
        .fullScreenCover(isPresented: $isDocumentBrowserPresented) {
            DocumentBrowser()
        }
    }

    private func buttonRemoveAllTapped() {
        store.removeAll()

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

@available(iOS 14, *)
private struct DocumentBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        DocumentBrowserViewController(forOpeningContentTypes: [UTType(filenameExtension: "pulse")].compactMap { $0 })
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {

    }
}

#if DEBUG
@available(iOS 14, *)
struct ConsoleContextMenu_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack {
                ConsoleContextMenu(store: .mock, isShowingAsText: .constant(false))
                Spacer()
            }
        }
    }
}
#endif

#endif
