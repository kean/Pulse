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

#if os(iOS)
    var body: some View {
        HStack {
            if let date = date {
                Text(title)
                Spacer()
                let binding = Binding(get: { date }, set: { self.date = $0 })
                DatePicker(title, selection: binding)
                    .labelsHidden()
                Button(action: { self.date = nil }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .padding(.leading, 6)
                .padding(.trailing, -6)
            } else {
                Button("Add \(title) Date") {
                    date = Date()
                }
            }
        }
    }
#endif

#if os(macOS)
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Toggle(title, isOn: $isEnabled)
                Spacer()
            }
            DatePicker(title, selection: $date)
                .disabled(!isEnabled)
                .fixedSize()
                .labelsHidden()
        }
    }
#endif
}

#endif
