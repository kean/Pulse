// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS)
import UniformTypeIdentifiers

@available(iOS 13.0, *)
public struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var console: ConsoleViewModel

    @State private var isDocumentBrowserPresented = false

    public init(store: LoggerStore = .default) {
        self.model = SettingsViewModel(store: store)
        self.console = ConsoleViewModel(store: store, contentType: .all)
    }
    
    init(model: SettingsViewModel, console: ConsoleViewModel) {
        self.model = model
        self.console = console
    }
    
    public var body: some View {
        Form {
            if let details = model.details {
                Section {
                    NavigationLink(destination: StoreDetailsView(model: details)) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(Color.primary)
                            Text("Store Info")
                                .foregroundColor(Color.primary)
                        }
                    }
                }
            }

            if !model.isReadonly {
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
                        .disabled(console.messages.isEmpty)
                        .opacity(console.messages.isEmpty ? 0.33 : 1)
                }
                if #available(iOS 14.0, *) {
                    if console.context.store === RemoteLogger.shared.store {
                        Section {
                            RemoteLoggerSettingsView(model: .shared)
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Settings")
        .navigationBarItems(leading: model.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
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

@available(iOS 13.0, *)
final class SettingsViewModel: ObservableObject {
    private let store: LoggerStore

    var onDismiss: (() -> Void)?

    init(store: LoggerStore) {
        self.store = store
    }

    var isReadonly: Bool {
        store.isReadonly
    }
        
    var details: StoreDetailsViewModel? {
        store.info.map { StoreDetailsViewModel(storeURL: store.storeURL, info: $0) }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 13.0, *)
struct ConsoleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView(model: SettingsViewModel(store: .mock), console: ConsoleViewModel(store: .mock))
        }
    }
}
#endif
#endif

// MARK: - Helpers
#if os(iOS) || os(watchOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
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

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ButtonRemove: View {
    let title: String
    let alert: String
    let action: () -> Void

    @State private var isShowingRemoveConfirmationAlert = false

    var body: some View {
        let button =
            Button(action: {
                self.isShowingRemoveConfirmationAlert = true
            }) {
                #if os(watchOS)
                Label(title, systemImage: "trash")
                #else
                HStack {
                    Image(systemName: "trash")
                    Text(title)
                }
                #endif
            }
            .alert(isPresented: $isShowingRemoveConfirmationAlert) {
                Alert(
                    title: Text(alert),
                    primaryButton: .destructive(Text(title), action: action),
                    secondaryButton: .cancel()
                )
            }

        #if os(watchOS)
        button
        #else
        button.foregroundColor(.red)
        #endif
    }
}

#endif
