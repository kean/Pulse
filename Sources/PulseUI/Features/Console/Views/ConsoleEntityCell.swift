// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Pulse
import CoreData

struct ConsoleEntityCell: View {
    let entity: NSManagedObject

    var body: some View {
        if let task = entity as? NetworkTaskEntity {
            NetworkRequestRow(task: task)
        } else if let message = entity as? LoggerMessageEntity {
            if let task = message.task {
                NetworkRequestRow(task: task)
            } else {
                NavigationLink(destination: LazyConsoleDetailsView(message: message)) {
                    ConsoleMessageCell(viewModel: .init(message: message))
                }
            }
        } else {
            fatalError("Unsupported entity: \(entity)")
        }
    }
}

private struct NetworkRequestRow: View {
    let task: NetworkTaskEntity

    var body: some View {
        NavigationLink(destination: LazyNetworkInspectorView(task: task)) {
            ConsoleTaskCell(viewModel: .init(task: task))
        }
    }
}

// Create the underlying ViewModel lazily.
private struct LazyNetworkInspectorView: View {
    let task: NetworkTaskEntity

    var body: some View {
        NetworkInspectorView(viewModel: .init(task: task))
    }
}

// Create the underlying ViewModel lazily.
private struct LazyConsoleDetailsView: View {
    let message: LoggerMessageEntity

    var body: some View {
        ConsoleMessageDetailsView(viewModel: .init(message: message))
    }
}
