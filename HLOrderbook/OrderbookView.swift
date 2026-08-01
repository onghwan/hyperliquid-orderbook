import SwiftUI

enum BookSide {
    case ask, bid

    var tint: Color {
        switch self {
        case .ask: Theme.ask
        case .bid: Theme.bid
        }
    }
}

/// The book itself: asks above, spread in the middle, bids below, in a scroll
/// view initially anchored on the spread so deeper levels are a swipe away.
/// Identifies the level whose stats popover is open.
/// The inspector pins a depth — "the Nth level out from the spread" — so as
/// the market moves, the highlight stays on the same rung of the ladder and
/// every figure in the panel updates live.
struct SelectedLevel: Equatable, Hashable {
    let isAsk: Bool
    let slot: Int
}

/// Where each row sits, so a scrubbing finger can be mapped to a level.
private struct RowFrame: Equatable {
    let level: SelectedLevel
    let rect: CGRect
}

private struct RowFramesKey: PreferenceKey {
    static let defaultValue: [RowFrame] = []
    static func reduce(value: inout [RowFrame], nextValue: () -> [RowFrame]) {
        value += nextValue()
    }
}

struct OrderbookView: View {
    var model: OrderbookViewModel

    @State private var selected: SelectedLevel?
    @State private var rowFrames: [RowFrame] = []
    /// Where the inspected level was last seen, so the popover stays put if
    /// its row is briefly unavailable.
    @State private var anchorRect: CGRect?

    // Rows track Dynamic Type, and their height grows with them so taller
    // text is never clipped.
    @ScaledMetric(relativeTo: .footnote) private var rowFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 24

    var body: some View {
        // Resolved once per render: the level the pinned distance reaches in
        // the current book, and the stats of sweeping there.
        let target = inspectorTarget

        VStack(spacing: 6) {
            columnHeader

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(model.asks.reversed()) { row in
                            levelRow(row, side: .ask, highlighted: target?.level)
                        }
                        SpreadRowView(spreadText: model.spreadText, percentText: model.spreadPercentText)
                            .id("spread")
                            .padding(.vertical, 4)
                        ForEach(model.bids) { row in
                            levelRow(row, side: .bid, highlighted: target?.level)
                        }
                    }
                    .padding(.bottom, 8)
                    .coordinateSpace(name: Self.bookSpace)
                    .onPreferenceChange(RowFramesKey.self) { frames in
                        rowFrames = frames
                        if let level = inspectorTarget?.level,
                           let rect = frames.first(where: { $0.level == level })?.rect {
                            anchorRect = rect
                        }
                    }
                    .overlay {
                        PressAndScrub(
                            onBegan: { inspect(at: $0) },
                            onMoved: { inspect(at: $0) }
                        )
                    }
                    // A single popover anchored to the target row, rather
                    // than one attached to each of the forty rows.
                    .overlay(alignment: .topLeading) { inspectorAnchor(target) }
                }
                .defaultScrollAnchor(.center)
                .scrollDisabled(selected != nil)
                .onChange(of: model.coin) {
                    dismissInspector()
                    withAnimation(.snappy) {
                        proxy.scrollTo("spread", anchor: .center)
                    }
                }
                // Regrouping rebuckets every price, so the inspected level no
                // longer exists in the new book.
                .onChange(of: model.grouping) { dismissInspector() }
            }
        }
        .overlay {
            if !model.hasBook {
                loadingOverlay
            }
        }
    }

    private static let bookSpace = "book"

    private var inspectorTarget: (level: SelectedLevel, stats: OrderbookViewModel.LevelStats)? {
        guard let selected,
              let depth = model.clampedDepth(selected.slot, isAsk: selected.isAsk),
              let stats = model.stats(atDepth: depth, isAsk: selected.isAsk) else { return nil }
        return (SelectedLevel(isAsk: selected.isAsk, slot: depth), stats)
    }

    @ViewBuilder
    private func inspectorAnchor(_ target: (level: SelectedLevel, stats: OrderbookViewModel.LevelStats)?) -> some View {
        // Falls back to the target's last known position, so the popover
        // stays put while that row briefly leaves the visible window.
        if let selected,
           let rect = target.flatMap({ t in rowFrames.first { $0.level == t.level }?.rect }) ?? anchorRect {
            Color.clear
                .frame(width: rect.width, height: rect.height)
                .popover(
                    isPresented: Binding(get: { true }, set: { if !$0 { dismissInspector() } }),
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: selected.isAsk ? .top : .bottom
                ) {
                    LevelStatsView(stats: target?.stats, coin: model.coin.rawValue)
                    // Without this the popover becomes a sheet on iPhone.
                    .presentationCompactAdaptation(.popover)
                }
                // Position with padding, not offset: offset is a render-time
                // transform the popover's anchor resolution ignores.
                .padding(.leading, rect.minX)
                .padding(.top, rect.minY)
        }
    }

    private func levelRow(_ row: OrderbookViewModel.Row, side: BookSide, highlighted: SelectedLevel?) -> some View {
        let level = SelectedLevel(isAsk: side == .ask, slot: row.slot)
        let isSelected = highlighted == level
        return LevelRowView(
            row: row,
            side: side,
            fontSize: rowFontSize,
            height: rowHeight,
            isSelected: isSelected
        )
        // Skips re-rendering rows whose content didn't change in a snapshot.
        .equatable()
        .background {
            // Row positions are stable while scrolling, so this publishes
            // once per layout rather than per frame.
            if !row.isEmpty {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: RowFramesKey.self,
                        value: [RowFrame(level: level, rect: geo.frame(in: .named(Self.bookSpace)))]
                    )
                }
            }
        }
    }

    private func level(at point: CGPoint) -> SelectedLevel? {
        rowFrames.first { $0.rect.contains(point) }?.level
    }

    private func dismissInspector() {
        selected = nil
        anchorRect = nil
    }

    /// Pins the inspector to the depth of the level under the finger. Only
    /// ever called during a recognised press, so ordinary drags still scroll
    /// the book.
    private func inspect(at point: CGPoint) {
        guard let hit = level(at: point), hit != selected else { return }
        Haptics.selection()
        selected = hit
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("Price (USDC)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Size (\(model.unitLabel))")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Total (\(model.unitLabel))")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 8)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Waiting for the book…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }
}

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

/// What a market order sweeping down to the pinned depth would cost.
/// Values refresh in place while the popover stays open.
struct LevelStatsView: View {
    let stats: OrderbookViewModel.LevelStats?
    let coin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let stats {
                row("Distance from Mid", stats.distance)
                row("Average Price", stats.averagePrice)
                row("Total (\(coin))", stats.totalCoin)
                row("Total (USDC)", stats.totalUsdc)
            }
        }
        .padding(18)
        .frame(width: 268)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

struct SpreadRowView: View {
    let spreadText: String
    let percentText: String

    var body: some View {
        HStack(spacing: 18) {
            Text("Spread")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(spreadText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(percentText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
    }
}
