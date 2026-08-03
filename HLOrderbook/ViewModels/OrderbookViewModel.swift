import SwiftUI
import Observation

@MainActor
@Observable
final class OrderbookViewModel {
    enum Coin: String, CaseIterable, Identifiable {
        case btc = "BTC"
        case eth = "ETH"

        var id: String { rawValue }

        /// Bundled logo in the asset catalog.
        var iconName: String {
            switch self {
            case .btc: "CoinBTC"
            case .eth: "CoinETH"
            }
        }
    }

    enum Direction {
        case up, down, flat
    }

    /// Display unit for the Size and Total columns.
    enum SizeUnit: String, CaseIterable, Identifiable {
        case coin
        case usdc

        var id: String { rawValue }
    }

    /// What it would take to sweep the book from the spread down to a depth.
    struct LevelStats: Equatable {
        var distance: String
        var averagePrice: String
        var totalCoin: String
        var totalUsdc: String
    }

    /// One visual slot of the book. Slots have a fixed identity ("ask-3") so
    /// SwiftUI updates row contents in place instead of inserting/removing
    /// rows, which keeps the book visually stable while prices move.
    struct Row: Identifiable, Equatable {
        let id: String
        let slot: Int               // 0 = best level of its side
        var rawPrice = ""
        var priceText = ""
        var sizeText = ""
        var totalText = ""
        var depth: CGFloat = 0      // 0…1 share of the deepest visible total
        var flashTick = 0           // bumped when this slot should flash
        var isEmpty = true
    }

    static let depthLevels = 20
    /// Minimum interval between UI applies; bursts of frames are coalesced
    /// down to the latest snapshot.
    private static let applyInterval: Duration = .milliseconds(100)
    /// The spread updates at most this often. `bbo` reports every top-of-book
    /// change, down to transients while makers re-quote, which the row would
    /// otherwise strobe through during fast markets.
    private static let summaryInterval: Duration = .milliseconds(500)
    /// Decimals shown for coin-denominated sizes and totals.
    private static let coinSizeDecimals = 5

    private(set) var asks: [Row]    // asks[0] is the best ask
    private(set) var bids: [Row]    // bids[0] is the best bid
    /// Mark price from `activeAssetCtx` — the exchange's own price, so it
    /// stays exact no matter how coarsely the book is grouped. Empty while it
    /// waits: whatever sits here is the frame the header's digits roll away
    /// from when the price arrives.
    private(set) var priceText = ""
    private(set) var priceDirection: Direction = .flat
    private(set) var spreadText = "—"
    private(set) var spreadPercentText = "—"
    private(set) var hasBook = false
    /// Surfaced only when it goes wrong: a first connection takes a moment and
    /// the spinner already covers that, but a dropped one leaves stale numbers
    /// on screen looking live.
    private(set) var connection: HyperliquidSocket.State = .connecting
    var isStale: Bool { connection == .reconnecting }
    /// False until the first mark arrives for this market.
    var hasPrice: Bool { previousMark != nil }

    /// Restored on launch, so the app opens on the market last looked at.
    var coin: Coin = .btc {
        didSet {
            guard coin != oldValue else { return }
            Haptics.selection()
            store.set(coin.rawValue, forKey: Self.coinKey)
            resetContext()
            resubscribe()
        }
    }

    private static let coinKey = "selectedCoin"

    /// The feed parameters behind one price-grouping choice.
    struct Grouping: Hashable {
        let nSigFigs: Int?
        let mantissa: Int?

        static let finest = Grouping(nSigFigs: nil, mantissa: nil)
    }

    struct GroupingOption: Identifiable, Equatable {
        let grouping: Grouping
        let label: String
        var id: String { label }
    }

    /// Grouping choices for the current market, labelled with the tick size
    /// each one produces. `n` significant figures on a price with `d` integer
    /// digits buckets prices into steps of 10^(d - n); `mantissa` (valid only
    /// at 5 significant figures) widens the finest bucket to 2× or 5×.
    var groupingOptions: [GroupingOption] {
        guard let digits = priceDigits else { return [] }
        // Finest first: the menu opens upward from the toolbar and renders its
        // entries in reverse, so this puts the coarsest on top.
        return PriceGrid.tickSteps(integerDigits: digits).map { tick in
            GroupingOption(
                grouping: Grouping(nSigFigs: tick.nSigFigs, mantissa: tick.mantissa),
                label: formatTick(tick.step)
            )
        }
    }

    var groupingLabel: String {
        groupingOptions.first { $0.grouping == grouping }?.label ?? "—"
    }

    /// Digit count of the current price, which sets every tick size. Falls
    /// back to the mark price so re-grouping — which empties the book until
    /// the next snapshot — doesn't blank the toolbar's label.
    private var priceDigits: Int? {
        let raw = bidLevels.first?.px ?? askLevels.first?.px
        guard let price = raw.flatMap(Double.init) ?? previousMark else { return nil }
        return PriceGrid.integerDigits(of: price)
    }

    /// Decimals the selected tick needs, so a $0.1 book shows "1,869.0"
    /// while a $1 book shows "63,083".
    private var tickDecimals: Int {
        guard let digits = priceDigits else { return 0 }
        let step = PriceGrid.tickStep(
            integerDigits: digits,
            nSigFigs: grouping.nSigFigs,
            mantissa: grouping.mantissa
        )
        return PriceGrid.decimals(forTick: step)
    }

    /// Price grouping requested from the feed.
    var grouping: Grouping = .finest {
        didSet {
            guard grouping != oldValue else { return }
            Haptics.selection()
            resubscribe()
        }
    }

    /// Unit for sizes and totals. Switching just re-renders the stored
    /// snapshot — no resubscribe needed.
    var sizeUnit: SizeUnit = .coin {
        didSet {
            guard sizeUnit != oldValue else { return }
            Haptics.selection()
            render()
        }
    }

    /// Label for the Size/Total column headers and the unit toggle.
    var unitLabel: String {
        sizeUnit == .coin ? coin.rawValue : "USDC"
    }

    private let socket = HyperliquidSocket()

    /// Levels from the latest l2Book snapshot.
    private var askLevels: [L2Level] = []
    private var bidLevels: [L2Level] = []
    private var lastBbo: BboData?
    private var previousMark: Double?

    /// The previous render, in coin units so the comparison is unaffected by
    /// the USDC display toggle.
    private var changes = BookChanges()

    private var pendingBook: L2Book?
    private var applyScheduled = false
    private var lastApply: ContinuousClock.Instant?
    private var summaryScheduled = false
    private var lastSummaryUpdate: ContinuousClock.Instant?

    private let priceFormatter: NumberFormatter
    private let sizeFormatter: NumberFormatter
    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        asks = (0..<Self.depthLevels).map { Row(id: "ask-\($0)", slot: $0) }
        bids = (0..<Self.depthLevels).map { Row(id: "bid-\($0)", slot: $0) }

        // Assigning here doesn't run the observer, so restoring costs no
        // haptic and no resubscribe — `start()` picks it up instead.
        if let saved = store.string(forKey: Self.coinKey), let restored = Coin(rawValue: saved) {
            coin = restored
        }

        priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .decimal
        sizeFormatter = NumberFormatter()
        sizeFormatter.numberStyle = .decimal

        socket.onBook = { [weak self] in self?.receive($0) }
        socket.onBbo = { [weak self] in self?.receive($0) }
        socket.onContext = { [weak self] in self?.receive($0) }
        socket.onState = { [weak self] in self?.connection = $0 }
    }

    // MARK: - Receiving frames

    // Named entry points rather than closures assigned in `init`: taking
    // frames is what this model does, so it may as well say so — and a test
    // can hand it one without a socket.

    func receive(_ book: L2Book) {
        pendingBook = book
        scheduleApply()
    }

    func receive(_ bbo: BboData) {
        lastBbo = bbo
        scheduleSummary()
    }

    func receive(_ context: AssetContext) {
        apply(context)
    }

    func start() {
        socket.start(with: currentSubscription)
    }

    func suspend() {
        socket.suspend()
    }

    func resume() {
        socket.resume()
    }

    // MARK: - Subscription

    private var currentSubscription: HyperliquidSocket.Subscription {
        .init(coin: coin.rawValue, nSigFigs: grouping.nSigFigs, mantissa: grouping.mantissa)
    }

    private func resubscribe() {
        resetBook()
        socket.update(subscription: currentSubscription)
    }

    private func resetBook() {
        hasBook = false
        askLevels = []
        bidLevels = []
        changes.reset()
        pendingBook = nil
        spreadText = "—"
        spreadPercentText = "—"
        // The row slots keep their contents on purpose: the view is about to
        // fold them away, and it needs something to fold.
    }

    /// Only the coin invalidates the header and bbo; re-grouping keeps them.
    private func resetContext() {
        previousMark = nil
        priceText = ""
        priceDirection = .flat
        lastBbo = nil
    }

    private func clear(_ row: inout Row) {
        row.rawPrice = ""
        row.priceText = ""
        row.sizeText = ""
        row.totalText = ""
        row.depth = 0
        row.isEmpty = true
    }

    // MARK: - Frame coalescing

    private func scheduleApply() {
        guard !applyScheduled else { return }
        let now = ContinuousClock.now
        if let lastApply, now - lastApply < Self.applyInterval {
            applyScheduled = true
            let wait = Self.applyInterval - (now - lastApply)
            Task { [weak self] in
                try? await Task.sleep(for: wait)
                guard let self else { return }
                self.applyScheduled = false
                self.applyPending()
            }
        } else {
            applyPending()
        }
    }

    private func applyPending() {
        guard let book = pendingBook else { return }
        pendingBook = nil
        lastApply = .now
        askLevels = Array(book.asks.prefix(Self.depthLevels))
        bidLevels = Array(book.bids.prefix(Self.depthLevels))
        render()
    }

    // MARK: - Rendering

    private func render() {
        updateSummary()
        guard !askLevels.isEmpty || !bidLevels.isEmpty else { return }

        let asksParsed = parse(askLevels)
        let bidsParsed = parse(bidLevels)
        let maxTotal = max(asksParsed.last?.total ?? 0, bidsParsed.last?.total ?? 0, .leastNonzeroMagnitude)
        let decimals = tickDecimals
        populate(rows: &asks, from: asksParsed, maxTotal: maxTotal, decimals: decimals, isAsk: true)
        populate(rows: &bids, from: bidsParsed, maxTotal: maxTotal, decimals: decimals, isAsk: false)
        changes.record(asks: asksParsed.map(\.asChange), bids: bidsParsed.map(\.asChange))

        hasBook = true
    }

    private struct ParsedLevel {
        let px: String
        let price: Double
        let coinSize: Double
        let size: Double    // in the selected display unit
        var total: Double

        var asChange: BookChanges.Level {
            .init(key: px, price: price, coinSize: coinSize)
        }
    }

    private func parse(_ levels: [L2Level]) -> [ParsedLevel] {
        var total = 0.0
        return levels.prefix(Self.depthLevels).map { level in
            let price = Double(level.px) ?? 0
            let coinSize = Double(level.sz) ?? 0
            let size = sizeUnit == .usdc ? coinSize * price : coinSize
            total += size
            return ParsedLevel(px: level.px, price: price, coinSize: coinSize, size: size, total: total)
        }
    }

    /// A row flashes on either kind of event worth noticing: a price level
    /// that wasn't in the book last render, or a sharp change in the size
    /// resting at an existing one.
    ///
    /// A level that merely scrolled in past the far edge of the visible
    /// window doesn't count — that happens on every shift and would light up
    /// the whole side at once.
    private func populate(rows: inout [Row], from levels: [ParsedLevel],
                          maxTotal: Double, decimals: Int, isAsk: Bool) {
        for index in rows.indices {
            guard index < levels.count else {
                clear(&rows[index])
                continue
            }
            let level = levels[index]
            if changes.isNotable(level.asChange, isAsk: isAsk) {
                rows[index].flashTick += 1
            }
            rows[index].rawPrice = level.px
            rows[index].priceText = formatPrice(level.px, decimals: decimals)
            rows[index].sizeText = formatSize(level.size)
            rows[index].totalText = formatSize(level.total)
            rows[index].depth = CGFloat(level.total / maxTotal)
            rows[index].isEmpty = false
        }
    }

    // MARK: - Spread

    private func scheduleSummary() {
        guard !summaryScheduled else { return }
        let now = ContinuousClock.now
        if let lastSummaryUpdate, now - lastSummaryUpdate < Self.summaryInterval {
            summaryScheduled = true
            let wait = Self.summaryInterval - (now - lastSummaryUpdate)
            Task { [weak self] in
                try? await Task.sleep(for: wait)
                guard let self else { return }
                self.summaryScheduled = false
                self.lastSummaryUpdate = .now
                self.updateSummary()
            }
        } else {
            lastSummaryUpdate = now
            updateSummary()
        }
    }

    /// Best bid/ask from a single source: the full-precision bbo stream when
    /// it has both sides, else the bucketed book. Mixing a full-precision
    /// side with a bucket-rounded one would fabricate spreads anywhere
    /// between one tick and the bucket width.
    private var bestPair: (bid: String, ask: String)? {
        if let bbo = lastBbo, let bid = bbo.bestBid?.px, let ask = bbo.bestAsk?.px {
            return (bid, ask)
        }
        guard let bid = bidLevels.first?.px, let ask = askLevels.first?.px else { return nil }
        return (bid, ask)
    }

    /// The spread row shows the true market spread from the full-precision
    /// bbo stream, matching Hyperliquid: grouping is a display convenience
    /// and shouldn't inflate the apparent cost of crossing the book.
    private func updateSummary() {
        guard let (bidRaw, askRaw) = bestPair,
              let bid = Double(bidRaw), let ask = Double(askRaw) else { return }

        let spread = ask - bid
        let mid = (bid + ask) / 2
        spreadText = trimmed(spread, decimals: max(decimals(in: bidRaw), decimals(in: askRaw)))
        let pct = mid > 0 ? spread / mid * 100 : 0
        spreadPercentText = String(format: "%.3f%%", pct)
    }

    private var currentMid: Double? {
        guard let (bidRaw, askRaw) = bestPair,
              let bestBid = Double(bidRaw), let bestAsk = Double(askRaw) else { return nil }
        return (bestBid + bestAsk) / 2
    }

    /// The deepest level actually available for a pinned depth: the inspector
    /// pins "the Nth level out from the spread", clamped when the book is
    /// momentarily shallower than that.
    // MARK: - Level inspector

    func clampedDepth(_ depth: Int, isAsk: Bool) -> Int? {
        let count = (isAsk ? askLevels : bidLevels).count
        guard count > 0 else { return nil }
        return min(depth, count - 1)
    }

    /// Cumulative figures for sweeping the book from the spread down to the
    /// given 0-based depth.
    func stats(atDepth depth: Int, isAsk: Bool) -> LevelStats? {
        guard let mid = currentMid, mid > 0 else { return nil }

        var coin = 0.0
        var notional = 0.0
        var deepest: Double?
        for level in (isAsk ? askLevels : bidLevels).prefix(depth + 1) {
            guard let price = Double(level.px), let size = Double(level.sz) else { continue }
            coin += size
            notional += size * price
            deepest = price
        }
        guard coin > 0, let deepest else { return nil }

        return LevelStats(
            distance: String(format: "%.4f%%", abs(deepest - mid) / mid * 100),
            averagePrice: format(notional / coin, decimals: tickDecimals),
            totalCoin: formatSize(coin, decimals: Self.coinSizeDecimals),
            totalUsdc: formatSize(notional, decimals: 0)
        )
    }

    // MARK: - Header price

    private func apply(_ context: AssetContext) {
        guard let mark = Double(context.ctx.markPx) else { return }

        if let previousMark, mark != previousMark {
            priceDirection = mark > previousMark ? .up : .down
        }
        previousMark = mark
        priceText = format(mark, decimals: PriceGrid.headerDecimals(for: mark))
    }

    // MARK: - Formatting

    /// Formats a price from the feed at the selected tick's precision, so
    /// every row lines up on the decimal point.
    private func formatPrice(_ raw: String, decimals: Int) -> String {
        guard let value = Double(raw) else { return raw }
        return format(value, decimals: decimals)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        priceFormatter.minimumFractionDigits = decimals
        priceFormatter.maximumFractionDigits = decimals
        return priceFormatter.string(from: value as NSNumber) ?? String(value)
    }

    /// Header prices aren't tied to the book's tick, so they drop trailing
    /// zeros: a mark of "63067.0" reads as "63,067".
    private func trimmed(_ value: Double, decimals: Int) -> String {
        priceFormatter.minimumFractionDigits = 0
        priceFormatter.maximumFractionDigits = decimals
        return priceFormatter.string(from: value as NSNumber) ?? String(value)
    }

    private func decimals(in raw: String) -> Int {
        guard let dot = raw.firstIndex(of: ".") else { return 0 }
        return raw.distance(from: raw.index(after: dot), to: raw.endIndex)
    }

    private func formatTick(_ step: Double) -> String {
        format(step, decimals: PriceGrid.decimals(forTick: step))
    }

    private func formatSize(_ value: Double) -> String {
        formatSize(value, decimals: sizeUnit == .coin ? Self.coinSizeDecimals : 0)
    }

    private func formatSize(_ value: Double, decimals: Int) -> String {
        sizeFormatter.minimumFractionDigits = decimals
        sizeFormatter.maximumFractionDigits = decimals
        return sizeFormatter.string(from: value as NSNumber) ?? String(value)
    }

}
