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

/// The book itself.
///
/// Narrow screens get the ladder: asks above, spread in the middle, bids
/// below, anchored on the spread. Wide ones get the two-column layout, bids
/// and asks side by side with their prices meeting in the middle — the same
/// twenty levels per side, but twice as many visible at once.
struct OrderbookView: View {
    var model: OrderbookViewModel
    var isWide = false

    /// Drives the opening animation: rows start stacked where the spread is
    /// and fan out to their places, nearest first.
    @State private var unfolded = false
    @State private var unfoldTask: Task<Void, Never>?

    @State private var selected: SelectedLevel?
    @State private var rowFrames: [RowFrame] = []
    /// Where the inspected level was last seen, so the popover stays put if
    /// its row is briefly unavailable.
    @State private var anchorRect: CGRect?

    // Height scales with the text, so taller type is never clipped.
    @ScaledMetric(relativeTo: .footnote) private var rowFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 24

    var body: some View {
        // Resolved once per render: the level the pinned depth reaches in the
        // current book, and the stats of sweeping there.
        let target = inspectorTarget

        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Group {
                    if isWide {
                        columns(highlighted: target?.level)
                    } else {
                        ladder(highlighted: target?.level)
                    }
                }
                .padding(.horizontal, 12)
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
            .scrollDisabled(selected != nil)
            // Centre on the spread once a book lands. Side by side there is no
            // spread row: both columns already start at the touch of the book.
            .onChange(of: model.hasBook) { _, loaded in
                unfoldTask?.cancel()
                guard loaded else {
                    unfolded = false
                    return
                }
                proxy.scrollTo(isWide ? "top" : "spread", anchor: isWide ? .top : .center)
                // A beat before unfolding, so the fold reads as finished
                // rather than reversing into the new book.
                unfoldTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    unfolded = true
                }
            }
            .onChange(of: isWide) { _, wide in
                proxy.scrollTo(wide ? "top" : "spread", anchor: wide ? .top : .center)
            }
            .onChange(of: model.coin) {
                dismissInspector()
                withAnimation(.snappy) {
                    proxy.scrollTo(isWide ? "top" : "spread", anchor: isWide ? .top : .center)
                }
            }
            // Regrouping rebuckets every price, so the inspected level no
            // longer exists in the new book.
            .onChange(of: model.grouping) { dismissInspector() }
        }
    }

    private static let bookSpace = "book"

    private func ladder(highlighted: SelectedLevel?) -> some View {
        VStack(spacing: 2) {
            ForEach(model.asks.reversed()) { row in
                levelRow(row, side: .ask, highlighted: highlighted)
            }
            // The figures fade on the rows' curve, unstaggered: they sit at
            // the seam, so they belong with the innermost rows. The bar hides
            // on the same timing, so the two leave together.
            SpreadRowView(
                spreadText: model.spreadText,
                percentText: model.spreadPercentText,
                textOpacity: unfolded ? 1 : 0
            )
            .id("spread")
            .padding(.vertical, 4)
            .animation(unfolded ? .easeOut(duration: 0.28) : .easeIn(duration: 0.2), value: unfolded)
            .opacity(model.hasBook ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: model.hasBook)
            ForEach(model.bids) { row in
                levelRow(row, side: .bid, highlighted: highlighted)
            }
        }
    }

    private func columns(highlighted: SelectedLevel?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                ForEach(model.bids) { row in
                    levelRow(row, side: .bid, highlighted: highlighted, layout: .leftColumn)
                }
            }
            VStack(spacing: 2) {
                ForEach(model.asks) { row in
                    levelRow(row, side: .ask, highlighted: highlighted, layout: .rightColumn)
                }
            }
        }
        // Both columns start at the spread, so the top of the content is
        // where the action is.
        .id("top")
    }

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

    private func levelRow(
        _ row: OrderbookViewModel.Row,
        side: BookSide,
        highlighted: SelectedLevel?,
        layout: LevelRowLayout = .ladder
    ) -> some View {
        let level = SelectedLevel(isAsk: side == .ask, slot: row.slot)
        let isSelected = highlighted == level
        return LevelRowView(
            row: row,
            side: side,
            fontSize: rowFontSize,
            height: rowHeight,
            isSelected: isSelected,
            layout: layout
        )
        // Skips re-rendering rows whose content didn't change in a snapshot.
        .equatable()
        // Three bare numbers read as nothing on their own, so the row speaks
        // as one element that names them. Empty slots aren't levels at all.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(row.isEmpty)
        .accessibilityLabel(rowLabel(row, side: side))
        // The inspector is a press and hold, which VoiceOver can't perform.
        // This is the same thing as a rotor action.
        .accessibilityAction(named: "Cost to fill") {
            Haptics.selection()
            selected = level
        }
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
        // Each animation sits directly above the property it drives: an
        // animation modifier only governs what's below it, so opacity first
        // or its fade is dropped and it switches outright.
        .opacity(unfolded ? 1 : 0)
        .animation(fadeAnimation(slot: row.slot), value: unfolded)
        // An offset, not a layout change: the fan-out costs one transform,
        // and the rows stay where the inspector expects them.
        .offset(y: unfolded ? 0 : collapsedOffset(slot: row.slot, isAsk: side == .ask))
        .animation(travelAnimation(slot: row.slot), value: unfolded)
    }

    /// Reads a row as a sentence rather than three unlabelled numbers. The
    /// side comes first: which half of the book you're in is the thing the
    /// colours convey and a screen reader otherwise loses.
    private func rowLabel(_ row: OrderbookViewModel.Row, side: BookSide) -> String {
        let sideName = side == .ask ? "Ask" : "Bid"
        return "\(sideName) \(row.priceText) USDC, size \(row.sizeText) \(model.unitLabel), "
            + "total \(row.totalText) \(model.unitLabel)"
    }

    private static let rowStagger = 0.006

    private func travelAnimation(slot: Int) -> Animation {
        unfolded
            ? .spring(response: 0.34, dampingFraction: 0.82).delay(delay(slot: slot))
            : .spring(response: 0.28, dampingFraction: 0.9).delay(delay(slot: slot))
    }

    private func fadeAnimation(slot: Int) -> Animation {
        unfolded
            ? .easeOut(duration: 0.28).delay(delay(slot: slot))
            : .easeIn(duration: 0.2).delay(delay(slot: slot))
    }

    /// Nearest the spread leads the way out; the outermost row leads the way
    /// back in.
    private func delay(slot: Int) -> Double {
        let step = unfolded ? slot : (OrderbookViewModel.depthLevels - 1 - slot)
        return Double(step) * Self.rowStagger
    }

    /// Where a row sits before it unfolds: stacked on the spread in the
    /// ladder, on the first row in the two-column layout.
    private func collapsedOffset(slot: Int, isAsk: Bool) -> CGFloat {
        let step = rowHeight + 2
        if isWide {
            return -CGFloat(slot) * step
        }
        return CGFloat(slot + 1) * step * (isAsk ? 1 : -1)
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
}
