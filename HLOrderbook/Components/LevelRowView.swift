import SwiftUI

/// How a row arranges its columns and grows its depth bar.
///
/// The ladder stacks both sides vertically; the side-by-side layout mirrors
/// the two halves around the middle, so prices sit shoulder to shoulder and
/// each bar grows away from them.
enum LevelRowLayout {
    case ladder         // price leading, bar hugs the trailing edge
    case leftColumn     // price trailing, bar hugs the trailing edge
    case rightColumn    // price leading, bar hugs the leading edge

    var priceIsTrailing: Bool { self == .leftColumn }
    var barAnchor: UnitPoint { self == .rightColumn ? .leading : .trailing }
}

/// A single price level. The depth bar grows away from the price, and the row
/// flashes when something notable happens at that price.
struct LevelRowView: View, Equatable {
    let row: OrderbookViewModel.Row
    let side: BookSide
    let fontSize: CGFloat
    let height: CGFloat
    let isSelected: Bool
    var layout: LevelRowLayout = .ladder

    @State private var flashOpacity = 0.0

    // Hand-written because @State isn't Equatable; comparing just the data is
    // what lets unchanged rows skip their body.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.side == rhs.side && lhs.isSelected == rhs.isSelected
            && lhs.fontSize == rhs.fontSize && lhs.height == rhs.height
            && lhs.layout == rhs.layout
    }

    var body: some View {
        HStack(spacing: 8) {
            if layout.priceIsTrailing {
                total
                size
                price
            } else {
                price
                size
                total
            }
        }
        .font(.system(size: fontSize, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 8)
        .frame(height: height)
        .background {
            // An anchored scale is a pure transform — no per-row
            // GeometryReader and no layout pass when the depth changes.
            RoundedRectangle(cornerRadius: 3)
                .fill(side.tint.opacity(0.14))
                .scaleEffect(x: max(0.001, row.depth), y: 1, anchor: layout.barAnchor)
                .animation(.easeOut(duration: 0.22), value: row.depth)
        }
        .overlay {
            if flashOpacity > 0 || isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .fill(side.tint.opacity(flashOpacity))
                    // Semantic, so the highlight reads in both appearances.
                    .overlay { if isSelected { RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.12)) } }
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: row.flashTick) {
            flashOpacity = 0.3
            withAnimation(.easeOut(duration: 0.8)) { flashOpacity = 0 }
        }
        .opacity(row.isEmpty ? 0 : 1)
    }

    private var price: some View {
        Text(row.priceText)
            .foregroundStyle(side.tint)
            .frame(maxWidth: .infinity, alignment: layout.priceIsTrailing ? .trailing : .leading)
    }

    private var size: some View {
        Text(row.sizeText)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var total: some View {
        Text(row.totalText)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
