// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct PlaceholderView: View {
    var imageName: String?
    let title: String
    var subtitle: String?

    #if os(tvOS)
    private let iconSize: CGFloat = 150
    #else
    private let iconSize: CGFloat = 70
    #endif

    #if os(macOS)
    private let maxWidth: CGFloat = .infinity
    #elseif os(tvOS)
    private let maxWidth: CGFloat = .infinity
    #else
    private let maxWidth: CGFloat = 280
    #endif

    var body: some View {
        VStack {
            imageName.map(Image.init(systemName:))
                .font(.system(size: iconSize, weight: .light))
            Spacer().frame(height: 8)
            Text(title)
                .font(.title)
                .multilineTextAlignment(.center)
            if let subtitle = self.subtitle {
                Spacer().frame(height: 10)
                Text(subtitle)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: maxWidth, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
    }
}
