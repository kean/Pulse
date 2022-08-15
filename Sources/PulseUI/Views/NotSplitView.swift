// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct NotSplitView: View, NSViewControllerRepresentable {
    private let views: [AnyView]
    private let isPanelOneCollaped: Bool
    private let isPanelTwoCollaped: Bool
    private let isVertical: Bool

    init<V1: View, V2: View>(
        _ v1: V1,
        _ v2: V2,
        isPanelOneCollaped: Bool = false,
        isPanelTwoCollaped: Bool = false,
        isVertical: Bool
    ) {
        self.views = [AnyView(v1), AnyView(v2)]
        self.isPanelOneCollaped = isPanelOneCollaped
        self.isPanelTwoCollaped = isPanelTwoCollaped
        self.isVertical = isVertical
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let vc = NSSplitViewController()
        vc.splitViewItems = views.map {
            NSSplitViewItem(viewController: NSHostingController(rootView: $0))
        }
        vc.splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)
        return vc
    }

    func updateNSViewController(_ nsViewController: NSSplitViewController, context: Context) {
        nsViewController.splitView.isVertical = isVertical
        nsViewController.splitViewItems[0].isCollapsed = isPanelOneCollaped
        nsViewController.splitViewItems[1].isCollapsed = isPanelTwoCollaped
    }
}

#endif
