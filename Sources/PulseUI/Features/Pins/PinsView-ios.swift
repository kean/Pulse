// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

@available(iOS 13.0, *)
public struct PinsView: View {
    @ObservedObject var model: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var shared: ShareItems?
    private var context: AppContext { model.context }

    public init(store: LoggerStore = .default) {
        self.model = ConsoleViewModel(store: store, contentType: .pins)
    }

    init(model: ConsoleViewModel) {
        self.model = model
    }
    
    public var body: some View {
        contents
            .navigationBarTitle(Text("Pins"))
            .navigationBarItems(
                leading: model.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } },
                trailing:
                    Button(action: model.removeAllPins) { Image(systemName: "trash") }
                    .disabled(model.messages.isEmpty)
            )
    }

    @ViewBuilder
    private var contents: some View {
        if model.messages.isEmpty {
            placeholder
                .navigationBarTitle(Text("Pins"))
        } else {
            List {
                ConsoleMessagesForEach(context: context, messages: model.messages, searchCriteriaViewModel: .init())
            }
            .listStyle(PlainListStyle())
        }
    }

    private var placeholder: PlaceholderView {
        PlaceholderView(imageName: "pin.circle", title: "No Pins", subtitle: "Pin messages using the context menu or from the details page")
    }
}

#if DEBUG
@available(iOS 13.0, *)
struct PinsView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            PinsView(model: .init(store: .mock))
            PinsView(model: .init(store: .mock))
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif

#endif
