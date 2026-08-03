import Foundation

/// The arithmetic behind price grouping, kept apart from the view model so it
/// can be reasoned about — and tested — on its own.
///
/// Hyperliquid buckets the book by significant figures, but traders think in
/// tick sizes. Everything here converts between the two.
enum PriceGrid {
    /// Significant figures at the feed's finest grouping, and the width the
    /// header price holds itself to.
    static let significantDigits = 5

    /// Digits before the decimal point, which set every tick size at this
    /// price magnitude. Nil for a price that can't have one.
    static func integerDigits(of price: Double) -> Int? {
        guard price > 0 else { return nil }
        return Int(floor(log10(price))) + 1
    }

    /// The tick that a grouping produces. `n` significant figures on a price
    /// with `d` integer digits buckets prices into steps of 10^(d - n), and
    /// `mantissa` widens that step to 2× or 5×.
    static func tickStep(integerDigits digits: Int, nSigFigs: Int?, mantissa: Int?) -> Double {
        pow(10.0, Double(digits - (nSigFigs ?? significantDigits))) * Double(mantissa ?? 1)
    }

    /// Decimals a tick needs to be written exactly: a $0.1 tick needs one, a
    /// $1 tick none.
    static func decimals(forTick step: Double) -> Int {
        step < 1 ? max(0, Int(ceil(-log10(step)))) : 0
    }

    /// Decimals the header price shows, from its magnitude rather than a table
    /// of coins: five significant figures. BTC near $63,000 shows none, ETH
    /// near $1,900 shows one, and the count only moves at a power of ten.
    static func headerDecimals(for price: Double) -> Int {
        guard let digits = integerDigits(of: price) else { return 0 }
        return min(8, max(0, significantDigits - digits))
    }

    /// Every tick the feed can produce at this price magnitude, finest first.
    /// `mantissa` is only valid at five significant figures, so the 2× and 5×
    /// steps exist only there.
    static func tickSteps(integerDigits digits: Int) -> [(nSigFigs: Int?, mantissa: Int?, step: Double)] {
        let finest = tickStep(integerDigits: digits, nSigFigs: nil, mantissa: nil)
        let fine: [(Int?, Int?, Double)] = [
            (nil, nil, finest),
            (significantDigits, 2, finest * 2),
            (significantDigits, 5, finest * 5),
        ]
        let coarse: [(Int?, Int?, Double)] = [4, 3, 2].map { n in
            (n, nil, tickStep(integerDigits: digits, nSigFigs: n, mantissa: nil))
        }
        return (fine + coarse).map { (nSigFigs: $0.0, mantissa: $0.1, step: $0.2) }
    }
}
