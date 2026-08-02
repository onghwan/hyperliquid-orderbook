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

/// Identifies the level whose stats popover is open. The inspector pins a
/// depth — "the Nth level out from the spread" — so as the market moves, the
/// highlight stays on the same rung of the ladder and every figure in the
/// panel updates live.
struct SelectedLevel: Equatable {
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

/// The book itself: asks above, spread in the middle, bids below, in a scroll
/// view initially anchored on the spread so deeper levels are a swipe away.
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
        // Resolved once per render: the level the pinned depth reaches in the
        // current book, and the stats of sweeping there.
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
        ProgressView()
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }
}
