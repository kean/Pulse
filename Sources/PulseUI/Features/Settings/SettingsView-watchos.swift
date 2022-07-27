// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(tvOS) || os(watchOS)

struct SettingsView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            if !viewModel.store.isReadonly {
                ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
            }
#if os(watchOS)
            Button(action: viewModel.tranferStore) {
                Label(viewModel.fileTransferStatus.title, systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.fileTransferStatus.isButtonDisabled)
            .alert(item: $viewModel.fileTransferError) { error in
                Alert(title: Text("Transfer Failed"), message: Text(error.message), dismissButton: .cancel(Text("Ok")))
            }
#endif
            if viewModel.store === RemoteLogger.shared.store, #available(tvOS 14.0, *) {
                RemoteLoggerSettingsView(viewModel: .shared)
            }
        }
#if os(tvOS)
        .frame(maxWidth: 800)
#endif
    }
}

#endif
