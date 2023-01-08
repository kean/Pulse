// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)
@available(iOS 14, *)
struct DateRangePicker: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        if let date = date {
            editView(date: date)
        } else {
            addView
        }
    }

    @ViewBuilder
    private func editView(date: Date) -> some View {
        HStack {
            let binding = Binding(get: { date }, set: { self.date = $0 })
            DatePicker(title, selection: binding)
                .labelsHidden()
            Spacer()
            Button(action: { self.date = nil }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var addView: some View {
#if os(iOS)
            Button("Add \(title) Date") {
                date = Date()
            }
#else
            HStack {
                Button("Add \(title) Date") {
                    date = Date()
                }
                Spacer()
            }
#endif
    }
}
#endif
