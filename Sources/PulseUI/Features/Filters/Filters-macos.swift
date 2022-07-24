// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

struct FilterSectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    let reset: () -> Void
    let isDefault: Bool
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
            }
            Spacer()
            Button(action: reset) {
                Image(systemName: "arrow.uturn.left")
            }
            .foregroundColor(.secondary)
            .disabled(isDefault)
            Button(action: { isEnabled.toggle() }) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isDefault ? .secondary : .accentColor)
            }
            .disabled(isDefault)
        }.buttonStyle(PlainButtonStyle())
    }
}

extension Filters {
    static let preferredWidth: CGFloat = 230
    static let formSpacing: CGFloat = 16
    static let formPadding = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 6)
    static let contentTopInset: CGFloat = 8
    
    @ViewBuilder
    static func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
        }.padding(.leading, 13)
    }
}

struct FiltersSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack {
            content()
        }
        .padding(.leading, 12)
        .padding(.top, Filters.contentTopInset)
    }
}

#endif
