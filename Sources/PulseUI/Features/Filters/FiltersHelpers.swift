// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)

enum Filters {
    typealias ContentType = NetworkSearchCriteria.ContentTypeFilter.ContentType

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

    static func sizeUnitPicker(_ selection: Binding<NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit>) -> some View {
        #if os(iOS)
        Picker("Size Unit", selection: selection) {
            Text("Bytes").tag(NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.bytes)
            Text("Kilobytes").tag(NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.kilobytes)
            Text("Megabytes").tag(NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.megabytes)
        }
        #else
        Picker("Size Unit", selection: selection) {
            Text("Bytes").tag(NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.bytes)
            Text("KB").tag(NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.kilobytes)
            Text("MB").tag(NetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.megabytes)
        }
        #endif
    }

    static func responseSourcePicker(_ selection: Binding<NetworkSearchCriteria.NetworkingFilter.Source>) -> some View {
        Picker("Response Source", selection: selection) {
            Text("Any").tag(NetworkSearchCriteria.NetworkingFilter.Source.any)
            Text("Network").tag(NetworkSearchCriteria.NetworkingFilter.Source.network)
            Text("Cache").tag(NetworkSearchCriteria.NetworkingFilter.Source.cache)
        }
    }

    static func taskTypePicker(_ selection: Binding<NetworkSearchCriteria.NetworkingFilter.TaskType>) -> some View {
        Picker("Task Type", selection: selection) {
            Text("Any").tag(NetworkSearchCriteria.NetworkingFilter.TaskType.any)
            Text("Data").tag(NetworkSearchCriteria.NetworkingFilter.TaskType.some(.dataTask))
            Text("Download").tag(NetworkSearchCriteria.NetworkingFilter.TaskType.some(.downloadTask))
            Text("Upload").tag(NetworkSearchCriteria.NetworkingFilter.TaskType.some(.uploadTask))
            Text("Stream").tag(NetworkSearchCriteria.NetworkingFilter.TaskType.some(.streamTask))
            Text("WebSocket").tag(NetworkSearchCriteria.NetworkingFilter.TaskType.some(.webSocketTask))
        }
    }
}

struct FilterPickerButton: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .foregroundColor(Color.primary.opacity(0.9))
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .background(Color.secondaryFill)
        .cornerRadius(8)
    }
}

struct FiltersSection<Header: View, Content: View>: View {
    var isExpanded: Binding<Bool>
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    var isWrapped = true

    var body: some View {
#if os(iOS)
        Section(content: content, header: header)
#elseif os(macOS)
        DisclosureGroup(
            isExpanded: isExpanded,
            content: {
                if isWrapped {
                    VStack {
                        content()
                    }
                    .padding(EdgeInsets(top: Filters.contentTopInset, leading: 12, bottom: 0, trailing: 5))
                } else {
                    content()
                }
            },
            label: header
        )
#endif
    }
}

extension Filters {
    static func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
#if os(iOS)
        Toggle(title, isOn: isOn)
#elseif os(macOS)
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
        }
#endif
    }
}

#endif

#if os(macOS)
extension Filters {
    static let preferredWidth: CGFloat = 230
    static let formSpacing: CGFloat = 16
    static let formPadding = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 6)
    static let contentTopInset: CGFloat = 8
}
#endif
