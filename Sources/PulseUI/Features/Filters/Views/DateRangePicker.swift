// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct DateRangePicker: View {
    let title: String
    @Binding var date: Date?

#if os(macOS)
    var body: some View {
        HStack {
            Text(title + " Date")
            Spacer()
            contents
        }.frame(height: 24)
    }
#else
    var body: some View {
#if os(iOS)
        if #available(iOS 16, *) {
            ViewThatFits {
                horizontal

                VStack(alignment: .leading) {
                    Text(title + " Date")
                    contents
                }
            }
        } else {
            horizontal
        }
#else
        horizontal
#endif
    }

    private var horizontal: some View {
        HStack {
            Text(title)
            Spacer()
            contents
        }
    }
#endif

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
            let binding = Binding(get: { date }, set: { self.date = $0 })
            DatePicker(title, selection: binding)
                .environment(\.locale, Locale(identifier: "en_US"))
                .fixedSize()
                .labelsHidden()
            Button(action: { self.date = nil }) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
#if os(iOS)
            .padding(.trailing, -4)
#endif
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
