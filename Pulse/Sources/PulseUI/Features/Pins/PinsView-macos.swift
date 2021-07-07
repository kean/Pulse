// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

struct PinsView: View {
    @ObservedObject var model: PinsViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isShowingShareSheet = false
    private var context: AppContext { .init(store: model.store, pins: model.pins) }

    public var body: some View {
        messagesListView
            .frame(minWidth: 300, idealWidth: 400, maxWidth: 700)
            .toolbar(content: {
                Button(action: model.removeAll) {
                    Image(systemName: "trash")
                }
            })
            .background(ShareView(isPresented: $isShowingShareSheet) { [model.prepareForSharing()] })
    }

    @ViewBuilder
    private var messagesListView: some View {
        if model.messages.isEmpty {
            placeholder
                .frame(maxWidth: 200)
        } else {
            ZStack {
                let factory = ConsoleRowFactory(context: context, showInConsole: model.showInConsole)
                NotList(model: model.list, makeRowView: factory.makeRowView, onSelectRow: model.selectEntityAt, onDoubleClickRow: {
                    openMessage(model.list.elements[$0])
                })
                NavigationLink(destination: ConsoleDetailsRouter(model: model.details), isActive: .constant(true)) { EmptyView() }
                    .hidden()
            }
        }
    }

    private func openMessage(_ message: LoggerMessageEntity) {
        ExternalEvents.open = AnyView(
            model.details.makeDetailsRouter(for: message)
                .frame(minWidth: 500, idealWidth: 700, maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, minHeight: 500, idealHeight: 800, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
        )
        guard let url = URL(string: "com-github-kean-pulse://open-details") else { return }
        NSWorkspace.shared.open(url)
    }

    private var placeholder: PlaceholderView {
        PlaceholderView(imageName: "pin.circle", title: "No Pins", subtitle: "Pin messages using the context menu or from the details page")
    }
}

#if DEBUG
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
