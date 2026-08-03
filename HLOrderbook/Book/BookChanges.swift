import Foundation

/// What moved between one render of the book and the next, and which of those
/// moves is worth pointing at.
///
/// Kept apart from the view model because "notable" is a product decision
/// rather than a rendering one, and because it holds state that only these
/// rules read.
struct BookChanges {
    /// A level is notable when its resting size grows by at least this
    /// fraction of itself — a doubling — so routine churn stays quiet.
    static let notableGrowth = 1.0

    /// One level as the rules see it. `key` is the feed's own price string,
    /// which is exact where the parsed double isn't.
    struct Level: Equatable {
        let key: String
        let price: Double
        let coinSize: Double
    }

    private var seenAsks: Set<String> = []
    private var seenBids: Set<String> = []
    private var askEdge: Double?
    private var bidEdge: Double?
    private var sizes: [String: Double] = [:]

    /// True for a level worth drawing the eye to: one that wasn't in the book
    /// a moment ago, or whose resting size has at least doubled.
    ///
    /// A level that merely scrolled in past the far edge of the window is new
    /// to the view, not to the market, so it stays quiet. That's what the edge
    /// comparison rules out.
    func isNotable(_ level: Level, isAsk: Bool) -> Bool {
        // The first book has nothing to be a change from.
        guard !(isAsk ? seenAsks : seenBids).isEmpty else { return false }

        guard let previousSize = sizes[level.key] else {
            guard let edge = isAsk ? askEdge : bidEdge else { return false }
            // Inside the window we last showed, so the market put it there.
            return isAsk ? level.price <= edge : level.price >= edge
        }
        guard previousSize > 0 else { return false }
        // Growth only. Liquidity arriving is the thing worth seeing, and a
        // level that loses all of its size is gone rather than notable — which
        // an unsigned comparison would score as a full doubling.
        return (level.coinSize - previousSize) / previousSize >= Self.notableGrowth
    }

    /// Records what was just rendered, so the next render has something to
    /// compare against.
    mutating func record(asks: [Level], bids: [Level]) {
        seenAsks = Set(asks.map(\.key))
        seenBids = Set(bids.map(\.key))
        askEdge = asks.last?.price
        bidEdge = bids.last?.price
        sizes = Dictionary(
            (asks + bids).map { ($0.key, $0.coinSize) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    /// Forgets everything, so the next book counts as a first one. Changing
    /// market or grouping rebuckets every price, which would otherwise read as
    /// the whole book changing at once.
    mutating func reset() {
        self = BookChanges()
    }
}
