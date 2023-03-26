// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct PlaceholderView: View {
    var imageName: String?
    let title: String
    var subtitle: String?

    var body: some View {
        VStack {
            imageName.map(Image.init(systemName:))
                .font(.system(size: 70, weight: .light))
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
        .frame(maxWidth: .infinity, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
    }
}

#if DEBUG
struct PlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        PlaceholderView(imageName: "questionmark.folder", title: "Store Unavailable")
    }
}
#endif
