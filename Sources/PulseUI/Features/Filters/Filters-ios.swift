// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if !os(watchOS)

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
}

//@available(iOS 14.0, *)
//struct DurationPicker: View {
//    let title: String
//
//#if os(macOS)
//    var body: some View {
//        HStack {
//            Text(title + ":")
//                .foregroundColor(.secondary)
//                .frame(width: 42, alignment: .trailing)
//            TextField("", text: $value.value)
//            Picker("", selection: $value.unit) {
//                Text("min").tag(DurationFilterPoint.Unit.minutes)
//                Text("sec").tag(DurationFilterPoint.Unit.seconds)
//                Text("ms").tag(DurationFilterPoint.Unit.milliseconds)
//            }
//            .fixedSize()
//        }
//    }
//#else
//    var body: some View {
//        HStack {
//            Text(title)
//            Spacer()
//            TextField("Duration", text: $value.value)
//                .textFieldStyle(.roundedBorder)
//                .frame(width: 100)
//            Menu(content: {
//                Picker("", selection: $value.unit) {
//                    Text("min").tag(DurationFilterPoint.Unit.minutes)
//                    Text("sec").tag(DurationFilterPoint.Unit.seconds)
//                    Text("ms").tag(DurationFilterPoint.Unit.milliseconds)
//                }
//            }, label: {
//                FilterPickerButton(title: value.unit.localizedTitle)
//            })
//            .animation(.none)
//            .fixedSize()
//
//        }
//    }
//#endif
//}

struct DateRangePicker: View {
    let title: String
    @Binding var date: Date
    @Binding var isEnabled: Bool

    var body: some View {
#if os(iOS)
        if #available(iOS 14.0, *) {
            newBody
        } else {
            oldBody
        }
#else
        newBody
#endif
    }

    @ViewBuilder
    private var newBody: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Toggle(title, isOn: $isEnabled)
                    .fixedSize()
                    .labelsHidden()
            }
            HStack {
                DatePicker(title, selection: $date)
                    .labelsHidden()
                Spacer()
            }
        }.frame(height: 84)
    }

#if os(iOS)
    @ViewBuilder
    private var oldBody: some View {
        NavigationLink(destination: DatePicker(title, selection: $date)
            .navigationBarTitle(title)
            .labelsHidden()) {
                HStack {
                    Toggle(title, isOn: $isEnabled)
                        .fixedSize()
                        .labelsHidden()
                    Text(title)
                        .padding(.leading, 6)
                    Spacer()
                    Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))
                        .foregroundColor(.secondary)
                }
            }
    }
#endif
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
