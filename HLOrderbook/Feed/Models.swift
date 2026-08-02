import Foundation

/// One price level of the L2 book. `px` and `sz` arrive as decimal strings.
struct L2Level: Decodable, Equatable {
    let px: String
    let sz: String
    let n: Int
}

/// Payload of an `l2Book` frame. `levels[0]` are bids (descending),
/// `levels[1]` are asks (ascending).
struct L2Book: Decodable {
    let coin: String
    let time: UInt64
    let levels: [[L2Level]]

    var bids: [L2Level] { levels.indices.contains(0) ? levels[0] : [] }
    var asks: [L2Level] { levels.indices.contains(1) ? levels[1] : [] }
}

/// Reads only the channel of an incoming frame so we can decide how to decode
/// the rest.
struct ChannelPeek: Decodable {
    let channel: String
}

struct L2BookMessage: Decodable {
    let data: L2Book
}

/// Payload of a `bbo` frame: the current best bid and ask at full precision,
/// pushed whenever either changes. Feeds the spread display, which shows the
/// true market spread no matter how coarsely the book is grouped.
struct BboData: Decodable {
    let coin: String
    let time: UInt64
    let bbo: [L2Level?]

    var bestBid: L2Level? { bbo.indices.contains(0) ? bbo[0] : nil }
    var bestAsk: L2Level? { bbo.indices.contains(1) ? bbo[1] : nil }
}

struct BboMessage: Decodable {
    let data: BboData
}

/// Exchange-computed context for one asset. Unlike the book, these prices are
/// unaffected by the display grouping we request.
struct AssetContext: Decodable {
    struct Values: Decodable {
        let markPx: String
    }

    let coin: String
    let ctx: Values
}

struct AssetContextMessage: Decodable {
    let data: AssetContext
}
