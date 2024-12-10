//
//  RichTextView-tvOS.swift
//  Pulse
//
//  Created by seunghwan Lee on 12/1/24.
//

#if os(tvOS)
import UIKit
import SwiftUI
import Pulse
 
struct ScrollableTextView: UIViewRepresentable {
    var text: String?
    var attributedText: NSAttributedString?
    
    init(text: String? = nil, attributedText: AttributedString? = nil) {
        self.text = text
        if let attributedText {
            self.attributedText = NSAttributedString(attributedText)
        }
    }

    func makeUIView(context: UIViewRepresentableContext<ScrollableTextView>) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.isUserInteractionEnabled = true
        textView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        textView.bounces = true
        textView.contentInsetAdjustmentBehavior = .never
        textView.insetsLayoutMarginsFromSafeArea = false
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.indicatorStyle = .white
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<ScrollableTextView>) {
        if let attributedText {
            uiView.attributedText = attributedText
        } else if let text {
            uiView.text = text
        }
    }
}

struct RichTextView: View {
    let viewModel: RichTextViewModel
    
    var body: some View {
        if let attributedText = viewModel.attributedString {
            ScrollableTextView(attributedText: attributedText)
        } else {
            ScrollableTextView(text: viewModel.text)
        }
    }
}
#endif
