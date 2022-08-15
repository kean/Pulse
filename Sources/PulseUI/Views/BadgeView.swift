// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct BadgeView: View {
    let viewModel: BadgeViewModel

#if os(iOS)
    let font = Font.system(size: 11, weight: .regular)
    let padding = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
#elseif os(tvOS)
    let font = Font.body
    let padding = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
#elseif os(macOS)
    let font = Font.system(size: 10, weight: .regular)
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
        Text(viewModel.title)
            .font(font)
            .foregroundColor(viewModel.textColor)
            .padding(padding)
            .background(viewModel.color)
            .cornerRadius(cornerRadius)
    }
}

struct BadgeView_Previews: PreviewProvider {
    static var previews: some View {
        BadgeView(viewModel: BadgeViewModel(title: "DEBUG", color: Color.red.opacity(0.3)))
            .previewLayout(.sizeThatFits)
    }
}

struct BadgeViewModel {
    let title: String
    let color: Color
    var textColor: Color = .primary
}
