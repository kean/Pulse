// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersTaskTypeCell: View {
    @Binding var selection: ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType

    var body: some View {
        Picker("Task Type", selection: $selection) {
            Text("Any").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.any)
            Text("Data").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.dataTask))
            Text("Download").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.downloadTask))
            Text("Upload").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.uploadTask))
            Text("Stream").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.streamTask))
            Text("WebSocket").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.webSocketTask))
        }
    }
}
