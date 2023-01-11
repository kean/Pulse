// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

enum ConsoleFilters {
    typealias ContentType = ConsoleNetworkSearchCriteria.ContentTypeFilter.ContentType

    static func contentTypesPicker(selection: Binding<ContentType>) -> some View {
        Picker("Content Type", selection: selection) {
            Section {
                Text("Any").tag(ContentType.any)
                Text("JSON").tag(ContentType.json)
                Text("Text").tag(ContentType.plain)
            }
            Section {
                Text("HTML").tag(ContentType.html)
                Text("CSS").tag(ContentType.css)
                Text("CSV").tag(ContentType.csv)
                Text("JS").tag(ContentType.javascript)
                Text("XML").tag(ContentType.xml)
                Text("PDF").tag(ContentType.pdf)
            }
            Section {
                Text("Image").tag(ContentType.anyImage)
                Text("JPEG").tag(ContentType.jpeg)
                Text("PNG").tag(ContentType.png)
                Text("GIF").tag(ContentType.gif)
                Text("WebP").tag(ContentType.webp)
            }
            Section {
                Text("Video").tag(ContentType.anyVideo)
            }
        }
    }

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

#if os(macOS)
extension ConsoleFilters {
    static let preferredWidth: CGFloat = 290
    static let formSpacing: CGFloat = 16
    static let formPadding = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 6)
}
#endif
