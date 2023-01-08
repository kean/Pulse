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
    @Binding var date: Date
    @Binding var isEnabled: Bool

#if os(iOS)
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                DatePicker(title, selection: $date)
                    .labelsHidden()
            }
            Spacer()
            Toggle(title, isOn: $isEnabled)
                .labelsHidden()
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
