import SwiftUI

extension View {
    /// iOS 26's soft scroll edge effect, which fades content where it meets a
    /// system bar. A no-op on older systems, where the book simply clips.
    func softScrollEdges() -> some View {
        modifier(SoftScrollEdges())
    }

    /// The same softening at the top, which the system effect doesn't cover:
    /// it keys off system bars (the tab bar, here) and a custom
    /// `safeAreaInset` isn't one, so rows would otherwise run into the status
    /// bar at full contrast.
    func fadingTopEdge(_ height: CGFloat = 60) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: height)
                Color.black
            }
            .ignoresSafeArea()
        }
    }
}

private struct SoftScrollEdges: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content
        }
    }
}
