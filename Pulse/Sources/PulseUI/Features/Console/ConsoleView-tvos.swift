// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(tvOS)

@available(tvOS 14, *)
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
        NavigationView {
            List {
                ConsoleMessagesForEach(context: model.context, messages: model.messages, searchCriteria: $model.searchCriteria)
            }
        }
        .navigationBarTitle(Text("Console"))
    }
}

#if DEBUG
@available(tvOS 14, *)
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
