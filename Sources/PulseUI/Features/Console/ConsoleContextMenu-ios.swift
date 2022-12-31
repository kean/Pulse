// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

import UniformTypeIdentifiers

@available(iOS 14.0, *)
struct ConsoleContextMenu: View {
    let store: LoggerStore

    @State private var isShowingSettings = false
    @State private var isShowingStoreInfo = false
    @State private var isDocumentBrowserPresented = false

    var body: some View {
        Menu {
            Section {
                Button(action: { isShowingStoreInfo = true }) {
                    Label("Store Info", systemImage: "info.circle")
                }
                if !store.isArchive {
                    Button(action: { isDocumentBrowserPresented = true }) {
                        Label("Browse Stores", systemImage: "doc")
                    }
                }
            }
            Section {
                Button(action: { isShowingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
            }
            if !store.isArchive {
                Section {
                    if #available(iOS 15.0, *) {
                        Button(role: .destructive, action: buttonRemoveAllTapped) {
                            Label("Remove Message", systemImage: "trash")
                        }
                    } else {
                        Button(action: buttonRemoveAllTapped) {
                            Label("Remove Message", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationView {
                SettingsView(store: store)
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

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
#endif
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

#if DEBUG
@available(iOS 14.0, *)
struct ConsoleContextMenu_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleContextMenu(store: .mock)
        }
    }
}
#endif

#endif
