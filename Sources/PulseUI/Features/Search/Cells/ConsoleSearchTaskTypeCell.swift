// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchTaskTypeCell: View {
    @Binding var selection: ConsoleSearchCriteria.Networking.TaskType

    var body: some View {
        Picker("Task Type", selection: $selection) {
            Text("Any").tag(ConsoleSearchCriteria.Networking.TaskType.any)
            Text("Data").tag(ConsoleSearchCriteria.Networking.TaskType.some(.dataTask))
            Text("Download").tag(ConsoleSearchCriteria.Networking.TaskType.some(.downloadTask))
            Text("Upload").tag(ConsoleSearchCriteria.Networking.TaskType.some(.uploadTask))
            Text("Stream").tag(ConsoleSearchCriteria.Networking.TaskType.some(.streamTask))
            Text("WebSocket").tag(ConsoleSearchCriteria.Networking.TaskType.some(.webSocketTask))
        }
    }
}
