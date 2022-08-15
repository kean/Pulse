// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import Foundation

struct ToastView<Content>: View where Content: View {
    let content: () -> Content
    var dismissDelay: TimeInterval = 3.0

    func dismissDelay(_ delay: TimeInterval) -> Self {
        var copy = self
        copy.dismissDelay = delay
        return copy
    }

    var body: some View {
        content()
            .foregroundColor(Color.black)
            .padding()
            .background(Color.white)
            .cornerRadius(40)
            .overlay(
                RoundedRectangle(cornerRadius: 40)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
               )
            .shadow(color: Color.black.opacity(0.1), radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/, x: /*@START_MENU_TOKEN@*/0.0/*@END_MENU_TOKEN@*/, y: /*@START_MENU_TOKEN@*/0.0/*@END_MENU_TOKEN@*/)
            .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .center)
    }
}

extension ToastView {
    func show() {
        ToastManager.shared.show(self)
    }
}

final class ToastManager {
    static let shared = ToastManager()

    var queue = [EnqueuedToast]()

    private var isShowingToast = false

    struct EnqueuedToast {
        let vc: UIViewController
        let dismissDelay: TimeInterval
    }

    init() {}

    @objc func swipeRecognized() {
        queue.first.map(\.vc).map(dismissToast)
    }

    func show<Content: View>(_ toast: ToastView<Content>) {
        let vc = UIHostingController(rootView: toast)
        queue.append(EnqueuedToast(vc: vc, dismissDelay: toast.dismissDelay))
        showToastIfNeeded()
    }

    func showToastIfNeeded() {
        guard !isShowingToast else {
            return
        }
        guard let enqueuedToast = queue.first,
              let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first,
              let container = window.rootViewController else {
            return
        }

        isShowingToast = true

        let toast = enqueuedToast.vc
        toast.view.backgroundColor = .clear

        container.addChild(toast)
        container.view.addSubview(toast.view)

        let swipe = UISwipeGestureRecognizer(target: ToastManager.shared, action: #selector(ToastManager.swipeRecognized))
        swipe.direction = .down
        toast.view.addGestureRecognizer(swipe)

        let size = toast.view.systemLayoutSizeFitting(.zero)
        toast.view.bounds.size = CGSize(width: container.view.bounds.width, height: size.height + 10)
        toast.view.center = CGPoint(x: container.view.bounds.width / 2, y: container.view.bounds.height - toast.view.bounds.height - container.view.safeAreaInsets.bottom)

        toast.view.alpha = 0
        toast.view.transform = CGAffineTransform(translationX: 0, y: 44).scaledBy(x: 0.95, y: 0.95)

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            toast.view.alpha = 1
            toast.view.transform = .identity
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(enqueuedToast.dismissDelay))) {
                self.dismissToast(toast)
            }
        }
    }

    func dismissToast(_ toast: UIViewController) {
        UIView.animate(withDuration: 0.33, delay: 0, options: [.beginFromCurrentState]) {
            toast.view.alpha = 0
            toast.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: 10)
        } completion: { _ in
            guard let line = self.queue.firstIndex(where: { $0.vc === toast }) else { return }
            self.queue.remove(at: line)

            toast.view.removeFromSuperview()
            toast.removeFromParent()

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.isShowingToast = false
                self.showToastIfNeeded()
            }
        }
    }
}

#if DEBUG

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        ToastView {
            HStack {
                Image(systemName: "archivebox")
                Text("Archive created (6 KB)")
            }
        }
        .previewLayout(.fixed(width: 400, height: 200))
    }
}

#endif

#endif
