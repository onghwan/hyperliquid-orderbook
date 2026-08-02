import SwiftUI

extension View {
    /// Liquid Glass on iOS 26, a blurred material on older systems, so a
    /// floating bar reads as a layer above the content scrolling beneath it.
    func glassBackground(cornerRadius: CGFloat) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

private struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
