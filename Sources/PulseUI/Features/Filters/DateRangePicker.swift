// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)

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
        macosBody
#endif
    }

#if os(iOS)
    @ViewBuilder
    private var newBody: some View {
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

#if os(macOS)
    @ViewBuilder
    var macosBody: some View {
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
