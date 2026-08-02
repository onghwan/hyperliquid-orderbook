import SwiftUI
import UIKit

/// A press-and-hold that reports where the finger is, and keeps reporting as
/// it moves.
///
/// SwiftUI's own gestures can't do this inside a `ScrollView`: a
/// `DragGesture` with no minimum distance claims the touch before the scroll
/// view's pan can start, so the book stops scrolling. A `UILongPressGestureRecognizer`
/// arbitrates properly — a quick swipe fails the press and scrolls, while a
/// hold cancels the pan and takes over.
struct PressAndScrub: UIViewRepresentable {
    var minimumDuration: TimeInterval = 0.35
    var onBegan: (CGPoint) -> Void
    var onMoved: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        // Plain and hit-testable: a recognizer only receives touches that
        // hit-test to its own view. Scrolling is unaffected, since the scroll
        // view's pan recognizer sits above this in the view hierarchy and
        // sees the same touches.
        let view = UIView()
        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        recognizer.minimumPressDuration = minimumDuration
        // Generous, so the press survives the finger travelling once it has
        // been recognised; movement before that still fails it into a scroll.
        recognizer.allowableMovement = 24
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onMoved = onMoved
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBegan: onBegan, onMoved: onMoved)
    }

    final class Coordinator: NSObject {
        var onBegan: (CGPoint) -> Void
        var onMoved: (CGPoint) -> Void

        init(onBegan: @escaping (CGPoint) -> Void, onMoved: @escaping (CGPoint) -> Void) {
            self.onBegan = onBegan
            self.onMoved = onMoved
        }

        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            let point = recognizer.location(in: recognizer.view)
            switch recognizer.state {
            case .began: onBegan(point)
            case .changed: onMoved(point)
            default: break
            }
        }
    }
}
