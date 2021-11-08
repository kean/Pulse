// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import PulseCore
import CoreData
import Combine
import AppKit

struct ConsoleMessageListView: View {
    @ObservedObject private var model: ConsoleViewModel

    init(model: ConsoleViewModel) {
        self.model = model
    }

    var body: some View {
        ZStack {
            let factory = ConsoleRowFactory(context: model.context, showInConsole: nil)
            NotList(model: model.list, makeRowView: factory.makeRowView, onSelectRow: model.selectEntityAt, onDoubleClickRow: {
                openMessage(model.list.elements[$0])
            }, isEmphasizedRow: {
                model.matches.isEmpty || model.isMatch(model.list.elements[$0])
            })
            NavigationLink(destination: ConsoleDetailsRouter(model: model.details), isActive: .constant(true)) { EmptyView() }
                .hidden()
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
}

struct ConsoleDetailsRouter: View {
    @ObservedObject var model: ConsoleDetailsRouterViewModel

    var body: some View {
        if let selectedEntity = model.selectedEntity {
            model.makeDetailsRouter(for: selectedEntity)
                .frame(minWidth: 480)
        } else {
            Text("No Selection")
                .font(.title)
                .foregroundColor(.secondary)
                .toolbar(content: {
                    Spacer()
                })
        }
    }
}

#endif
