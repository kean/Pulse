// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct BadgeView: View {
    let model: BadgeViewModel

    #if os(iOS)
    let font = Font.system(size: 11, weight: .regular)
    let padding = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
    #elseif os(tvOS)
    let font = Font.body
    let padding = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
    #else
    let font = Font.system(size: 10, weight: .regular)
    let padding = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
    #endif
    
    #if os(macOS)
    var cornerRadius: CGFloat = 4
    #else
    let cornerRadius: CGFloat = 20
    #endif
    
    var body: some View {
        Text(model.title)
            .font(font)
            .foregroundColor(model.textColor)
            .padding(padding)
            .background(model.color)
            .cornerRadius(cornerRadius)
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct BadgeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BadgeView(model: BadgeViewModel(title: "DEBUG", color: Color.red.opacity(0.3)))
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct BadgeViewModel {
    let title: String
    let color: Color
    var textColor: Color = .primary
}
