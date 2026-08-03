import Testing
@testable import HLOrderbook

/// The arithmetic that turns Hyperliquid's significant-figure grouping into
/// the tick sizes the UI shows, checked against real BTC and ETH magnitudes.
struct PriceGridTests {
    @Test func integerDigitsCountsDigitsBeforeThePoint() {
        #expect(PriceGrid.integerDigits(of: 63_055) == 5)
        #expect(PriceGrid.integerDigits(of: 1_846.7) == 4)
        #expect(PriceGrid.integerDigits(of: 9.99) == 1)
        #expect(PriceGrid.integerDigits(of: 0.05) == -1)
    }

    @Test func integerDigitsRejectsPricesThatCantHaveThem() {
        #expect(PriceGrid.integerDigits(of: 0) == nil)
        #expect(PriceGrid.integerDigits(of: -1) == nil)
    }

    /// Five significant figures on a five-digit price is a $1 tick; on a
    /// four-digit price it is $0.1.
    @Test func finestTickFollowsThePriceMagnitude() {
        #expect(PriceGrid.tickStep(integerDigits: 5, nSigFigs: nil, mantissa: nil) == 1)
        #expect(PriceGrid.tickStep(integerDigits: 4, nSigFigs: nil, mantissa: nil) == 0.1)
    }

    @Test func fewerSignificantFiguresWidenTheTick() {
        #expect(PriceGrid.tickStep(integerDigits: 5, nSigFigs: 4, mantissa: nil) == 10)
        #expect(PriceGrid.tickStep(integerDigits: 5, nSigFigs: 3, mantissa: nil) == 100)
        #expect(PriceGrid.tickStep(integerDigits: 5, nSigFigs: 2, mantissa: nil) == 1_000)
    }

    @Test func mantissaMultipliesTheFinestTick() {
        #expect(PriceGrid.tickStep(integerDigits: 5, nSigFigs: 5, mantissa: 2) == 2)
        #expect(PriceGrid.tickStep(integerDigits: 5, nSigFigs: 5, mantissa: 5) == 5)
    }

    @Test func decimalsCoverTheTickExactly() {
        #expect(PriceGrid.decimals(forTick: 1) == 0)
        #expect(PriceGrid.decimals(forTick: 10) == 0)
        #expect(PriceGrid.decimals(forTick: 0.1) == 1)
        #expect(PriceGrid.decimals(forTick: 0.01) == 2)
        #expect(PriceGrid.decimals(forTick: 0.5) == 1)
    }

    /// BTC shows whole dollars, ETH one decimal — both five significant
    /// figures, with no per-coin table anywhere.
    @Test func headerHoldsFiveSignificantFigures() {
        #expect(PriceGrid.headerDecimals(for: 63_055) == 0)
        #expect(PriceGrid.headerDecimals(for: 1_846.7) == 1)
        #expect(PriceGrid.headerDecimals(for: 234.56) == 2)
        #expect(PriceGrid.headerDecimals(for: 12.345) == 3)
    }

    /// Past $100,000 the integer part alone is wider than five figures, so the
    /// count floors at zero rather than going negative and rounding the price.
    @Test func headerNeverDropsIntegerDigits() {
        #expect(PriceGrid.headerDecimals(for: 100_001) == 0)
        #expect(PriceGrid.headerDecimals(for: 999_999) == 0)
    }

    @Test func headerCapsDecimalsForVerySmallPrices() {
        #expect(PriceGrid.headerDecimals(for: 0.05) == 6)
        #expect(PriceGrid.headerDecimals(for: 0.0000001) <= 8)
    }

    @Test func headerDecimalsAreZeroForAnUnusablePrice() {
        #expect(PriceGrid.headerDecimals(for: 0) == 0)
    }

    /// The six steps the grouping menu offers, finest first.
    @Test func tickStepsRunFinestToCoarsest() {
        let steps = PriceGrid.tickSteps(integerDigits: 5).map(\.step)
        #expect(steps == [1, 2, 5, 10, 100, 1_000])
    }

    @Test func tickStepsScaleDownWithThePrice() {
        let steps = PriceGrid.tickSteps(integerDigits: 4).map(\.step)
        #expect(steps == [0.1, 0.2, 0.5, 1, 10, 100])
    }

    /// `mantissa` is only valid alongside five significant figures, so the
    /// coarser steps must not carry one.
    @Test func onlyTheFineStepsCarryAMantissa() {
        let steps = PriceGrid.tickSteps(integerDigits: 5)
        let widened = steps.filter { $0.mantissa != nil }
        let coarse = steps.filter { ($0.nSigFigs ?? 5) < 5 }
        let widenedAreFinest = widened.allSatisfy { $0.nSigFigs == 5 }
        let coarseHaveNoMantissa = coarse.allSatisfy { $0.mantissa == nil }
        #expect(widenedAreFinest)
        #expect(coarseHaveNoMantissa)
    }

    /// The finest step asks for no parameters at all, which is what the feed
    /// treats as its default precision.
    @Test func theFinestStepRequestsNoGrouping() {
        let finest = PriceGrid.tickSteps(integerDigits: 5).first
        #expect(finest?.nSigFigs == nil)
        #expect(finest?.mantissa == nil)
    }
}
