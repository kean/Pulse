// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchTaskTypeCell: View {
    @Binding var selection: ConsoleFilers.Networking.TaskType

    var body: some View {
        Picker("Task Type", selection: $selection) {
            Text("Any").tag(ConsoleFilers.Networking.TaskType.any)
            Text("Data").tag(ConsoleFilers.Networking.TaskType.some(.dataTask))
            Text("Download").tag(ConsoleFilers.Networking.TaskType.some(.downloadTask))
            Text("Upload").tag(ConsoleFilers.Networking.TaskType.some(.uploadTask))
            Text("Stream").tag(ConsoleFilers.Networking.TaskType.some(.streamTask))
            Text("WebSocket").tag(ConsoleFilers.Networking.TaskType.some(.webSocketTask))
        }
    }
}
