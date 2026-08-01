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
