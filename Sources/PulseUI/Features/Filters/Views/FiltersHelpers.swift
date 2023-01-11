// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

enum ConsoleFilters {
    static func responseSourcePicker(_ selection: Binding<ConsoleNetworkSearchCriteria.NetworkingFilter.Source>) -> some View {
        Picker("Response Source", selection: selection) {
            ForEach(ConsoleNetworkSearchCriteria.NetworkingFilter.Source.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
    }

    static func taskTypePicker(_ selection: Binding<ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType>) -> some View {
        Picker("Task Type", selection: selection) {
            Text("Any").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.any)
            Text("Data").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.dataTask))
            Text("Download").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.downloadTask))
            Text("Upload").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.uploadTask))
            Text("Stream").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.streamTask))
            Text("WebSocket").tag(ConsoleNetworkSearchCriteria.NetworkingFilter.TaskType.some(.webSocketTask))
        }
    }
}

extension ConsoleFilters {
    static func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
#if os(macOS)
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
        }
#else
        Toggle(title, isOn: isOn)
#endif
    }
}
