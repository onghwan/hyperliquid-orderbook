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

    /// One visual slot of the book. Slots have a fixed identity ("ask-3") so
    /// SwiftUI updates row contents in place instead of inserting/removing
    /// rows, which keeps the book visually stable while prices move.
    struct Row: Identifiable, Equatable {
        let id: String
        var rawPrice = ""
        var priceText = ""
        var sizeText = ""
        var totalText = ""
        var depth: CGFloat = 0      // 0…1 share of the deepest visible total
        var isEmpty = true
    }

    static let depthLevels = 20
    /// Minimum interval between UI applies; bursts of frames are coalesced
    /// down to the latest snapshot.
    private static let applyInterval: Duration = .milliseconds(100)
    /// Decimals shown for coin-denominated sizes and totals.
    private static let coinSizeDecimals = 5

    private(set) var asks: [Row]    // asks[0] is the best ask
    private(set) var bids: [Row]    // bids[0] is the best bid
    /// Mark price from `activeAssetCtx` — the exchange's own price, so it
    /// stays exact no matter how coarsely the book is grouped.
    private(set) var priceText = "—"
    private(set) var priceDirection: Direction = .flat
    private(set) var spreadText = "—"
    private(set) var spreadPercentText = "—"
    private(set) var hasBook = false

    var coin: Coin = .btc {
        didSet {
            guard coin != oldValue else { return }
            Haptics.selection()
            resetContext()
            resubscribe()
        }
    }

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
        guard let px = bidLevels.first?.px ?? askLevels.first?.px,
              let price = Double(px), price > 0 else { return [] }
        let digits = Int(floor(log10(price))) + 1
        let finestStep = pow(10.0, Double(digits - 5))
        let fine = [
            (Grouping.finest, finestStep),
            (Grouping(nSigFigs: 5, mantissa: 2), finestStep * 2),
            (Grouping(nSigFigs: 5, mantissa: 5), finestStep * 5),
        ]
        let coarse = [4, 3, 2].map { n in
            (Grouping(nSigFigs: n, mantissa: nil), pow(10.0, Double(digits - n)))
        }
        // Listed finest-first: the menu opens upward from the toolbar and
        // renders the entries in reverse, so this puts the coarsest on top.
        return (fine + coarse).map { GroupingOption(grouping: $0.0, label: formatTick($0.1)) }
    }

    var groupingLabel: String {
        groupingOptions.first { $0.grouping == grouping }?.label ?? "—"
    }

    /// Decimals the selected tick needs, so a $0.1 book shows "1,869.0"
    /// while a $1 book shows "63,083".
    private var tickDecimals: Int {
        guard let px = bidLevels.first?.px ?? askLevels.first?.px,
              let price = Double(px), price > 0 else { return 0 }
        let digits = Int(floor(log10(price))) + 1
        var step = pow(10.0, Double(digits - (grouping.nSigFigs ?? 5)))
        step *= Double(grouping.mantissa ?? 1)
        return max(0, Int(ceil(-log10(step))))
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
    private var previousMark: Double?

    private var pendingBook: L2Book?
    private var applyScheduled = false
    private var lastApply: ContinuousClock.Instant?

    private let priceFormatter: NumberFormatter
    private let sizeFormatter: NumberFormatter

    init() {
        asks = (0..<Self.depthLevels).map { Row(id: "ask-\($0)") }
        bids = (0..<Self.depthLevels).map { Row(id: "bid-\($0)") }

        priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .decimal
        sizeFormatter = NumberFormatter()
        sizeFormatter.numberStyle = .decimal

        socket.onBook = { [weak self] book in
            self?.pendingBook = book
            self?.scheduleApply()
        }
        socket.onContext = { [weak self] ctx in
            self?.apply(ctx)
        }
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
        pendingBook = nil
        spreadText = "—"
        spreadPercentText = "—"
        for index in asks.indices { clear(&asks[index]) }
        for index in bids.indices { clear(&bids[index]) }
    }

    /// Only the coin invalidates the header; re-grouping keeps it live.
    private func resetContext() {
        previousMark = nil
        priceText = "—"
        priceDirection = .flat
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
        populate(rows: &asks, from: asksParsed, maxTotal: maxTotal, decimals: decimals)
        populate(rows: &bids, from: bidsParsed, maxTotal: maxTotal, decimals: decimals)
        hasBook = true
    }

    private struct ParsedLevel {
        let px: String
        let size: Double    // in the selected display unit
        var total: Double
    }

    private func parse(_ levels: [L2Level]) -> [ParsedLevel] {
        var total = 0.0
        return levels.prefix(Self.depthLevels).map { level in
            var size = Double(level.sz) ?? 0
            if sizeUnit == .usdc {
                size *= Double(level.px) ?? 0
            }
            total += size
            return ParsedLevel(px: level.px, size: size, total: total)
        }
    }

    private func populate(rows: inout [Row], from levels: [ParsedLevel], maxTotal: Double, decimals: Int) {
        for index in rows.indices {
            guard index < levels.count else {
                clear(&rows[index])
                continue
            }
            let level = levels[index]
            rows[index].rawPrice = level.px
            rows[index].priceText = formatPrice(level.px, decimals: decimals)
            rows[index].sizeText = formatSize(level.size)
            rows[index].totalText = formatSize(level.total)
            rows[index].depth = CGFloat(level.total / maxTotal)
            rows[index].isEmpty = false
        }
    }

    private func updateSummary() {
        guard let bidRaw = bidLevels.first?.px, let askRaw = askLevels.first?.px,
              let bid = Double(bidRaw), let ask = Double(askRaw) else { return }

        let spread = ask - bid
        let mid = (bid + ask) / 2
        spreadText = format(spread, decimals: tickDecimals)
        let pct = mid > 0 ? spread / mid * 100 : 0
        spreadPercentText = String(format: "%.3f%%", pct)
    }

    private func apply(_ context: AssetContext) {
        guard let mark = Double(context.ctx.markPx) else { return }

        if let previousMark, mark != previousMark {
            priceDirection = mark > previousMark ? .up : .down
        }
        previousMark = mark
        priceText = trimmed(mark, decimals: decimals(in: context.ctx.markPx))
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
        let decimals = step < 1 ? Int(-floor(log10(step))) : 0
        return format(step, decimals: decimals)
    }

    private func formatSize(_ value: Double) -> String {
        let decimals = sizeUnit == .coin ? Self.coinSizeDecimals : 0
        sizeFormatter.minimumFractionDigits = decimals
        sizeFormatter.maximumFractionDigits = decimals
        return sizeFormatter.string(from: value as NSNumber) ?? String(value)
    }

}
