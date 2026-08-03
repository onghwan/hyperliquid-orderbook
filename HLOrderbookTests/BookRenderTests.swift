import Testing
import Foundation
@testable import HLOrderbook

/// What the model makes of a snapshot: the twenty row slots, their running
/// totals, and the depth bars behind them.
///
/// The first frame renders synchronously — coalescing only defers a frame that
/// arrives within 100 ms of the last one — so these can assert straight after
/// handing one over.
@MainActor
struct BookRenderTests {
    private func model() -> OrderbookViewModel {
        let name = UUID().uuidString
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return OrderbookViewModel(store: store)
    }

    /// Bids descend and asks ascend, which is the order the feed sends.
    private func book(bids: [(px: String, sz: String)], asks: [(px: String, sz: String)]) -> L2Book {
        L2Book(coin: "BTC", time: 0, levels: [
            bids.map { L2Level(px: $0.px, sz: $0.sz, n: 1) },
            asks.map { L2Level(px: $0.px, sz: $0.sz, n: 1) },
        ])
    }

    private func evenBook(levels: Int = 3, size: String = "1") -> L2Book {
        book(
            bids: (0..<levels).map { (px: String(63_000 - $0), sz: size) },
            asks: (0..<levels).map { (px: String(63_001 + $0), sz: size) }
        )
    }

    @Test func aSnapshotFillsTheRowsAndMarksTheBookLoaded() {
        let model = model()
        model.receive(evenBook())
        #expect(model.hasBook)
        #expect(model.asks.prefix(3).allSatisfy { !$0.isEmpty })
        #expect(model.bids.prefix(3).allSatisfy { !$0.isEmpty })
    }

    /// Slot 0 is the level nearest the spread on each side.
    @Test func theFirstSlotHoldsTheBestLevel() {
        let model = model()
        model.receive(evenBook())
        #expect(model.asks[0].rawPrice == "63001")
        #expect(model.bids[0].rawPrice == "63000")
    }

    @Test func totalsAccumulateAwayFromTheSpread() {
        let model = model()
        model.receive(book(
            bids: [("63000", "1"), ("62999", "2"), ("62998", "3")],
            asks: [("63001", "1"), ("63002", "2"), ("63003", "3")]
        ))
        #expect(model.asks[0].totalText == "1.00000")
        #expect(model.asks[1].totalText == "3.00000")
        #expect(model.asks[2].totalText == "6.00000")
    }

    /// The bar is a share of the deepest total on either side, so the deepest
    /// row fills its width and nothing overflows it.
    @Test func depthIsAShareOfTheDeepestTotal() {
        let model = model()
        model.receive(book(
            bids: [("63000", "1")],
            asks: [("63001", "1"), ("63002", "3")]
        ))
        #expect(model.asks[1].depth == 1)
        #expect(model.asks[0].depth == 0.25)
        // The bid side is measured against the same maximum, not its own.
        #expect(model.bids[0].depth == 0.25)
        #expect(model.asks.allSatisfy { $0.depth <= 1 })
    }

    /// Twenty slots always exist. A shallower book leaves the rest empty
    /// rather than removing them, which is what keeps their identities stable.
    @Test func slotsBeyondTheSnapshotAreCleared() {
        let model = model()
        model.receive(evenBook(levels: 3))
        #expect(model.asks.count == OrderbookViewModel.depthLevels)
        #expect(model.asks[3].isEmpty)
        #expect(model.asks[3].priceText.isEmpty)
        #expect(model.asks[19].isEmpty)
    }

    /// A book that shrinks must clear the slots it no longer reaches, or stale
    /// levels would sit under the new ones.
    @Test func aShorterBookClearsWhatItNoLongerReaches() async throws {
        let model = model()
        model.receive(evenBook(levels: 5))
        #expect(model.asks[4].isEmpty == false)
        model.receive(evenBook(levels: 2))
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.asks[4].isEmpty)
    }

    /// Frames arriving inside the coalescing window don't each get a render.
    /// Only the newest is applied, and only once the window is up — which is
    /// what keeps a burst from queueing up stale work.
    @Test func aBurstOfFramesIsCoalescedToTheLatest() async throws {
        let model = model()
        model.receive(book(bids: [("63000", "1")], asks: [("63001", "1")]))
        #expect(model.asks[0].rawPrice == "63001")

        model.receive(book(bids: [("63010", "1")], asks: [("63011", "1")]))
        model.receive(book(bids: [("63020", "1")], asks: [("63021", "1")]))
        // Still the first one: neither of those has been applied yet.
        #expect(model.asks[0].rawPrice == "63001")

        try await Task.sleep(for: .milliseconds(200))
        // And when the window is up it is the newest, not the one in between.
        #expect(model.asks[0].rawPrice == "63021")
    }

    /// Row identities never change, however the book moves.
    @Test func slotIdentitiesSurviveANewSnapshot() {
        let model = model()
        let before = model.asks.map(\.id)
        model.receive(evenBook())
        model.receive(evenBook(levels: 5, size: "9"))
        #expect(model.asks.map(\.id) == before)
    }

    /// Switching units re-reads the snapshot the model already has: sizes are
    /// multiplied by price, and no new frame is needed.
    @Test func switchingUnitsRerendersTheStoredSnapshot() {
        let model = model()
        model.receive(book(bids: [("63000", "2")], asks: [("63001", "2")]))
        #expect(model.bids[0].sizeText == "2.00000")
        model.sizeUnit = .usdc
        #expect(model.bids[0].sizeText == "126,000")
        #expect(model.unitLabel == "USDC")
    }

    /// Five significant figures at this magnitude is a $1 tick, so prices show
    /// no decimals.
    @Test func pricesAreFormattedAtTheCurrentTick() {
        let model = model()
        model.receive(evenBook())
        #expect(model.asks[0].priceText == "63,001")
    }

    /// The grouping menu needs a price magnitude, which the book supplies.
    @Test func aBookGivesTheGroupingMenuItsTickSizes() {
        let model = model()
        #expect(model.groupingOptions.isEmpty)
        model.receive(evenBook())
        #expect(model.groupingOptions.map(\.label) == ["1", "2", "5", "10", "100", "1,000"])
    }

    /// The mark price comes from its own channel, not from the book.
    @Test func theHeaderPriceComesFromTheContextFrame() {
        let model = model()
        #expect(model.hasPrice == false)
        model.receive(AssetContext(coin: "BTC", ctx: .init(markPx: "63000.4")))
        #expect(model.hasPrice)
        #expect(model.priceText == "63,000")
        #expect(model.priceDirection == .flat)
    }

    @Test func theHeaderArrowFollowsTheMark() {
        let model = model()
        model.receive(AssetContext(coin: "BTC", ctx: .init(markPx: "63000")))
        model.receive(AssetContext(coin: "BTC", ctx: .init(markPx: "63010")))
        #expect(model.priceDirection == .up)
        model.receive(AssetContext(coin: "BTC", ctx: .init(markPx: "62990")))
        #expect(model.priceDirection == .down)
    }
}
