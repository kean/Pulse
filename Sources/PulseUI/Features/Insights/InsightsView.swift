// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import PulseCore
import SwiftUI

#if os(iOS)

public struct InsightsView: View {
    @ObservedObject var insights: LoggerStoreInsights

    public var body: some View {
        ScrollView {
            NetworkInspectorTransferInfoView(viewModel: .init(transferSize: insights.transferSize))
        }
    }
}

struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView(insights: LoggerStore.mock.insights!)
    }
}

#endif
