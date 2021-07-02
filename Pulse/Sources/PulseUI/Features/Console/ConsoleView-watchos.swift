// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(watchOS)
import WatchConnectivity

@available(watchOS 7.0, *)
public struct ConsoleView: View {
    @ObservedObject var model: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isShowingFiltersView = false
    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isStoreArchived = false

    public init(store: LoggerStore = .default) {
        self.model = ConsoleViewModel(store: store)
    }

    init(model: ConsoleViewModel) {
        self.model = model
    }

    public var body: some View {
        List {
            Button(action: model.tranferStore) {
                Label(model.fileTransferStatus.title, systemImage: "square.and.arrow.up")
            }.disabled(model.fileTransferStatus.isButtonDisabled)
            Button(action: { isShowingFiltersView = true }) {
                Label("Quick Filters", systemImage: "line.horizontal.3.decrease.circle")
            }
            ConsoleMessagesForEach(context: model.context, messages: model.messages, searchCriteria: $model.searchCriteria)
        }
        .navigationTitle("Console")
        .toolbar {
            ButtonRemoveAll(action: model.buttonRemoveAllMessagesTapped)
                .disabled(model.messages.isEmpty)
                .opacity(model.messages.isEmpty ? 0.33 : 1)
        }
        .alert(item: $model.fileTransferError) { error in
            Alert(title: Text("Transfer Failed"), message: Text(error.message), dismissButton: .cancel(Text("Ok")))
        }
        .sheet(isPresented: $isShowingFiltersView) {
            List(model.quickFilters) { filter in
                Button(action: {
                    filter.action()
                    isShowingFiltersView = false
                }) {
                    Label(filter.title, systemImage: filter.imageName)
                        .foregroundColor(filter.title == "Reset" ? Color.red : nil)
                }
            }
        }
    }
}

#if DEBUG
@available(watchOS 7.0, *)
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ConsoleView(model: .init(store: .mock))
            ConsoleView(model: .init(store: .mock))
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
