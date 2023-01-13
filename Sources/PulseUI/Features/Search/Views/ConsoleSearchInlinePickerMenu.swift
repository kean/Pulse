// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchInlinePickerMenu<Picker: View>: View {
    let title: String
    var width: CGFloat?
    @ViewBuilder var picker: () -> Picker
    
#if os(iOS)
    var body: some View {
        Menu(content: {
            picker()
        }, label: {
            Text(title)
                .font(.subheadline)
                .frame(width: width)
                .foregroundColor(Color.primary.opacity(0.9))
                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .background(Color.secondaryFill)
                .cornerRadius(8)
        })
        .animation(.none)
    }
#else
    var body: some View {
        picker()
    }
#endif
}
