// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
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

#endif

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

#if os(iOS) || os(tvOS)

struct FilterSectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    let reset: () -> Void
    let isDefault: Bool
    var isEnabled: Binding<Bool> = .constant(true)

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title.uppercased())
            }
            .font(.body)
            Spacer()

            Button(action: reset) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 34, height: 34)
            .disabled(isDefault)
        }.buttonStyle(.plain)
    }
}

#endif