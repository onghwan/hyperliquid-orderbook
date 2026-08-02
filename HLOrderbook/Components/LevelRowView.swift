import SwiftUI

/// A single price level. The depth bar grows from the trailing edge, and the
/// row flashes when something notable happens at that price.
struct LevelRowView: View, Equatable {
    let row: OrderbookViewModel.Row
    let side: BookSide
    let fontSize: CGFloat
    let height: CGFloat
    let isSelected: Bool

    @State private var flashOpacity = 0.0

    // Hand-written because @State isn't Equatable; comparing just the data is
    // what lets unchanged rows skip their body.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.side == rhs.side && lhs.isSelected == rhs.isSelected
            && lhs.fontSize == rhs.fontSize && lhs.height == rhs.height
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(row.priceText)
                .foregroundStyle(side.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.sizeText)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(row.totalText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: fontSize, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 8)
        .frame(height: height)
        .background {
            // A trailing-anchored scale is a pure transform — no per-row
            // GeometryReader and no layout pass when the depth changes.
            RoundedRectangle(cornerRadius: 3)
                .fill(side.tint.opacity(0.14))
                .scaleEffect(x: max(0.001, row.depth), y: 1, anchor: .trailing)
                .animation(.easeOut(duration: 0.22), value: row.depth)
        }
        .overlay {
            if flashOpacity > 0 || isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .fill(side.tint.opacity(flashOpacity))
                    .overlay { if isSelected { RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.1)) } }
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: row.flashTick) {
            flashOpacity = 0.3
            withAnimation(.easeOut(duration: 0.8)) { flashOpacity = 0 }
        }
        .opacity(row.isEmpty ? 0 : 1)
    }
}
