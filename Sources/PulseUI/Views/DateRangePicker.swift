// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

package struct DateRangePicker: View {
    package let title: String
    @Binding package var date: Date?

    package init(title: String, date: Binding<Date?>) {
        self.title = title
        self._date = date
    }

#if os(macOS)
    package var body: some View {
        HStack {
            Text(title + " Date")
            Spacer()
            contents
        }.frame(height: 24)
    }
#else
    package var body: some View {
#if os(iOS) || os(visionOS)
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
#if os(iOS) || os(visionOS)
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
