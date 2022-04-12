// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct QuickFilterViewModel: Identifiable {
    var id: String { title }
    let title: String
    let color: Color
    let imageName: String
    let action: () -> Void
}

#if os(iOS)
@available(iOS 13.0, *)
struct ConsoleQuickFiltersView: View {
    let filters: [QuickFilterViewModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(filters) {
                    QuickFilterView(model: $0)
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct QuickFilterView: View {
    let model: QuickFilterViewModel

    var body: some View {
        Button(action: model.action) {
            Text(model.title)
                .lineLimit(1)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color.primary.opacity(0.9))
                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .background(Color.secondaryFill)
                .cornerRadius(8)
        }.buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 13.0, *)
struct QuickFilterView_Previews: PreviewProvider {
    static var previews: some View {
        QuickFilterView(model: .init(title: "Test", color: .green, imageName: "", action: {}))
    }
}
#endif
