// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(tvOS)

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    var store: LoggerStore { viewModel.store }

    public init(store: LoggerStore = .shared) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(store: store))
    }

    public var body: some View {
        Form {
            sectionStoreDetails
#if os(watchOS)
            sectionTransferStore
#endif
            if !(store.options.contains(.readonly)) {
                Section {
                    Button(role: .destructive, action: viewModel.buttonRemoveAllMessagesTapped) {
                        Label("Remove Logs", systemImage: "trash")
                    }
                }
            }
            if viewModel.isRemoteLoggingAvailable {
                RemoteLoggerSettingsView(viewModel: .shared)
            }
        }
        .navigationTitle("Settings")
#if os(tvOS)
        .frame(maxWidth: 800)
#endif
    }
    
    private var sectionStoreDetails: some View {
        Section {
            NavigationLink(destination: StoreDetailsView(source: .store(viewModel.store))) {
                Label("Store Info", systemImage: "info.circle")
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
            SettingsView(store: .mock)
        }
    }
}
#endif
#endif
