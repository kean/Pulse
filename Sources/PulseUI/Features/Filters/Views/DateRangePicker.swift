// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)
struct DateRangePicker: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
#if os(iOS)
        contents
#else
        HStack {
            contents
            Spacer()
        }
#endif
    }

    @ViewBuilder
    private var contents: some View {
        if let date = date {
            editView(date: date)
        } else {
            setDateView
        }
    }

    @ViewBuilder
    private func editView(date: Date) -> some View {
        HStack {
#if os(macOS)
            Text(title)
            Spacer()
#endif
            let binding = Binding(get: { date }, set: { self.date = $0 })
            DatePicker(title, selection: binding)
                .environment(\.locale, Locale(identifier: "en_US"))
#if os(macOS)
                .fixedSize()
                .labelsHidden()
#endif
#if os(iOS)
            Spacer()
#endif
            Button(action: { self.date = nil }) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
            }
            .padding(.trailing, -8)
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var setDateView: some View {
        Button("Set \(title) Date") {
            date = Date()
        }
    }
}
#endif
