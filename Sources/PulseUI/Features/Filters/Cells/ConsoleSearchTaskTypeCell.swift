// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchTaskTypeCell: View {
    @Binding var selection: ConsoleFilters.Networking.TaskType

    var body: some View {
        Picker("Task Type", selection: $selection) {
            Text("Any").tag(ConsoleFilters.Networking.TaskType.any)
            Text("Data").tag(ConsoleFilters.Networking.TaskType.some(.dataTask))
            Text("Download").tag(ConsoleFilters.Networking.TaskType.some(.downloadTask))
            Text("Upload").tag(ConsoleFilters.Networking.TaskType.some(.uploadTask))
            Text("Stream").tag(ConsoleFilters.Networking.TaskType.some(.streamTask))
            Text("WebSocket").tag(ConsoleFilters.Networking.TaskType.some(.webSocketTask))
        }
    }
}
