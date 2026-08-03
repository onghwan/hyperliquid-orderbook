import Testing
import Foundation
@testable import HLOrderbook

/// Behaviour that doesn't need the socket: what the model restores at launch,
/// what it saves, and what the toolbar reads off it.
@MainActor
struct OrderbookViewModelTests {
    /// A store of its own per test, so nothing leaks between them or into the
    /// real app's defaults.
    private func emptyStore(_ name: String = UUID().uuidString) -> UserDefaults {
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    @Test func startsOnBitcoinWithNothingSaved() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.coin == .btc)
    }

    @Test func restoresTheSavedMarket() {
        let store = emptyStore()
        store.set("ETH", forKey: "selectedCoin")
        #expect(OrderbookViewModel(store: store).coin == .eth)
    }

    @Test func ignoresAnUnknownSavedMarket() {
        let store = emptyStore()
        store.set("DOGE", forKey: "selectedCoin")
        #expect(OrderbookViewModel(store: store).coin == .btc)
    }

    @Test func savesTheMarketWhenItChanges() {
        let store = emptyStore()
        let model = OrderbookViewModel(store: store)
        model.coin = .eth
        #expect(store.string(forKey: "selectedCoin") == "ETH")
    }

    @Test func waitsForAPriceBeforeReportingOne() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.hasPrice == false)
        // Empty, not a placeholder: whatever is here is the frame the
        // header's digits roll away from when the price arrives.
        #expect(model.priceText.isEmpty)
    }

    /// A first connection is the normal case, not a fault: the spinner already
    /// says the price is coming, so nothing extra should be on screen.
    @Test func doesNotReportStalenessBeforeTheFirstConnection() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.connection == .connecting)
        #expect(model.isStale == false)
    }

    @Test func startsWithNoBook() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.hasBook == false)
        let asksEmpty = model.asks.allSatisfy(\.isEmpty)
        let bidsEmpty = model.bids.allSatisfy(\.isEmpty)
        #expect(asksEmpty)
        #expect(bidsEmpty)
    }

    /// Fixed identities are what let SwiftUI update rows in place instead of
    /// inserting and removing them.
    @Test func rowSlotsHaveStableIdentities() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.asks.count == OrderbookViewModel.depthLevels)
        #expect(model.bids.count == OrderbookViewModel.depthLevels)
        #expect(model.asks.map(\.id).first == "ask-0")
        #expect(model.bids.map(\.id).last == "bid-19")
        #expect(Set(model.asks.map(\.id)).count == model.asks.count)
    }

    /// Without a price there is no magnitude to derive tick sizes from, so the
    /// menu has nothing to offer and the label falls back.
    @Test func offersNoGroupingUntilAPriceIsKnown() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.groupingOptions.isEmpty)
        #expect(model.groupingLabel == "—")
    }

    @Test func labelsSizesInTheSelectedUnit() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.unitLabel == "BTC")
        model.sizeUnit = .usdc
        #expect(model.unitLabel == "USDC")
        model.sizeUnit = .coin
        model.coin = .eth
        #expect(model.unitLabel == "ETH")
    }

    /// The finest grouping asks the feed for no parameters at all.
    @Test func defaultsToTheFinestGrouping() {
        let model = OrderbookViewModel(store: emptyStore())
        #expect(model.grouping == .finest)
        #expect(model.grouping.nSigFigs == nil)
        #expect(model.grouping.mantissa == nil)
    }
}
