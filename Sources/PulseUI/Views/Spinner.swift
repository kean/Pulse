// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(tvOS)

import UIKit

struct Spinner: View {
    var body: some View {
        if #available(iOS 14, tvOS 14, *) {
            ProgressView()
        } else {
            ActivityIndicator()
        }
    }
}

private struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView()
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        // Do nothing
    }
}

#else

struct Spinner: View {
    var body: some View {
        ProgressView()
    }
}

#if DEBUG
struct Spinner_Previews: PreviewProvider {
    static var previews: some View {
        Spinner()
    }
}
#endif

#endif
