//
//  RichTextView-tvos.swift
//  Pulse
//
//  Created by seunghwan Lee on 12/10/24.
//

#if os(tvOS)
import SwiftUI
import UIKit
 
struct ScrollableTextView: UIViewRepresentable {
    private let text: String?
    private let attributedText: AttributedString?
    
    init(text: String? = nil, attributedText: AttributedString? = nil) {
        self.text = text
        self.attributedText = attributedText
    }

    func makeUIView(context: UIViewRepresentableContext<ScrollableTextView>) -> UITextView {
        let textView = UITextView()
        textView.isUserInteractionEnabled = true
        textView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        
        if let attributedText {
            textView.attributedText = NSAttributedString(attributedText)
        } else if let text {
            textView.text = text
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Do nothing
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

