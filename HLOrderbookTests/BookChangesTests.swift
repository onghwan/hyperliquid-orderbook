import Testing
@testable import HLOrderbook

/// The rules behind the row flash. They exist to keep the effect rare enough
/// to mean something, so most of these check that a level stays quiet.
struct BookChangesTests {
    private func level(_ price: Double, _ size: Double) -> BookChanges.Level {
        .init(key: String(price), price: price, coinSize: size)
    }

    /// Twenty levels a side, a dollar apart, walking away from the spread.
    private func book(bestAsk: Double = 100, size: Double = 1) -> (asks: [BookChanges.Level], bids: [BookChanges.Level]) {
        let asks = (0..<20).map { level(bestAsk + Double($0), size) }
        let bids = (0..<20).map { level(bestAsk - 1 - Double($0), size) }
        return (asks, bids)
    }

    @Test func theFirstBookIsAllQuiet() {
        let changes = BookChanges()
        #expect(changes.isNotable(level(100, 5), isAsk: true) == false)
        #expect(changes.isNotable(level(99, 5), isAsk: false) == false)
    }

    @Test func anUnchangedLevelIsQuiet() {
        var changes = BookChanges()
        let first = book()
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(100, 1), isAsk: true) == false)
    }

    @Test func aDoubledLevelIsNotable() {
        var changes = BookChanges()
        let first = book(size: 1)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(100, 2), isAsk: true))
    }

    /// Just short of a doubling is the churn the threshold exists to ignore.
    @Test func aLevelThatGrowsLessThanDoubleIsQuiet() {
        var changes = BookChanges()
        let first = book(size: 1)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(100, 1.99), isAsk: true) == false)
    }

    /// The rule is about liquidity arriving, so a level losing size is quiet
    /// however much it loses — including all of it.
    @Test func aShrinkingLevelIsQuiet() {
        var changes = BookChanges()
        let first = book(size: 10)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(100, 1), isAsk: true) == false)
        #expect(changes.isNotable(level(100, 0), isAsk: true) == false)
    }

    /// A price the market has just opened, inside the window we were already
    /// showing.
    @Test func aNewLevelInsideTheWindowIsNotable() {
        var changes = BookChanges()
        let first = book(bestAsk: 100)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(100.5, 1), isAsk: true))
        #expect(changes.isNotable(level(98.5, 1), isAsk: false))
    }

    /// The window showed asks up to 119. A level at 130 isn't new to the
    /// market, only to the view, so it must stay quiet.
    @Test func aLevelScrollingInPastTheEdgeIsQuiet() {
        var changes = BookChanges()
        let first = book(bestAsk: 100)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(130, 1), isAsk: true) == false)
        #expect(changes.isNotable(level(50, 1), isAsk: false) == false)
    }

    /// Asks run up and bids run down, so "past the far edge" is a different
    /// comparison on each side. Asks reached 119 and bids reached 80, which
    /// puts 130 outside the ask window but well inside the bid one.
    @Test func theEdgeTestFollowsTheSideItIsOn() {
        var changes = BookChanges()
        let first = book(bestAsk: 100)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(130, 1), isAsk: true) == false)
        #expect(changes.isNotable(level(130, 1), isAsk: false))
    }

    /// Regrouping rebuckets every price, which would otherwise read as the
    /// whole book changing at once.
    @Test func resetMakesTheNextBookAFirstOne() {
        var changes = BookChanges()
        let first = book(size: 1)
        changes.record(asks: first.asks, bids: first.bids)
        #expect(changes.isNotable(level(100, 4), isAsk: true))
        changes.reset()
        #expect(changes.isNotable(level(100, 4), isAsk: true) == false)
    }

    /// Each side keeps its own history, so a quiet ask side doesn't silence a
    /// moving bid side.
    @Test func sidesAreTrackedSeparately() {
        var changes = BookChanges()
        changes.record(asks: [], bids: book().bids)
        #expect(changes.isNotable(level(100, 9), isAsk: true) == false)
        #expect(changes.isNotable(level(99, 2), isAsk: false))
    }
}
