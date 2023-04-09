// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Combine
import Pulse

struct StoreStatusView: View {
    let store: LoggerStore

    @State var isShowingDetails = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Image(systemName: "doc")
                .frame(height: 18, alignment: .center)
                .padding(.trailing, 8)
            VStack(alignment: .leading) {
                Text(store.storeURL.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
        .frame(maxWidth: 220)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator, lineWidth: 0.5)
        )
        .help(store.storeURL.path)
        .onTapGesture { isShowingDetails = true }
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            VStack {
                StoreDetailsView(source: .store(store))
                Spacer()
            }
            .frame(width: 320, height: 400)
        }
    }
}

#if DEBUG
struct Previews_RemoteLoggerClientStatusView_Previews: PreviewProvider {
    static var previews: some View {
        StoreStatusView(store: LoggerStore.mock)
            .frame(width: 220)
    }
}
#endif

#endif
