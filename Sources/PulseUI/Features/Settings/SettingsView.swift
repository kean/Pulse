// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(tvOS)

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    public init(store: LoggerStore = .shared) {
        // TODO: Fix ownership
        self.viewModel = SettingsViewModel(store: store)
    }
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Form {
            if #available(tvOS 14, *) {
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
            if #available(tvOS 14, *), viewModel.isRemoteLoggingAvailable {
                Section {
                    RemoteLoggerSettingsView(viewModel: .shared)
                }
            }
        }
        .backport.navigationTitle("Settings")
#if os(tvOS)
        .frame(maxWidth: 800)
#endif
    }
    
    @available(tvOS 14, *)
    private var sectionStoreDetails: some View {
        Section {
            NavigationLink(destination: StoreDetailsView(source: .store(viewModel.store))) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Store Info")
                }
            }
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
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
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
