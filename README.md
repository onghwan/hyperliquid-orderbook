# HLOrderbook

A native iOS orderbook widget streaming the live L2 book from Hyperliquid's
websocket feed, built with Swift/SwiftUI only — no third-party dependencies.

<p>
  <img src="docs/screenshot.png" width="300" alt="HLOrderbook — live BTC book" />
</p>
<p>
  <em>BTC/ETH · live depth · price grouping (nSigFigs/mantissa) · level
  inspector · haptics · Dynamic Type</em>
</p>

## Run

Open `HLOrderbook.xcodeproj` in Xcode 16+ and run the `HLOrderbook` scheme on
any iOS 17+ simulator or device. There is nothing to configure — the app
connects straight to `wss://api.hyperliquid.xyz/ws`.

## Features

- **Live L2 book** — subscribes to the `l2Book` channel; asks above, bids
  below, with the spread pinned between them. The list scrolls natively and is
  anchored on the spread, so deeper levels are a swipe away.
- **Symbol selection** — BTC / ETH via a searchable market-picker sheet; the
  pattern scales past two assets (another market is one enum case away).
  Switching re-subscribes on the live socket (no reconnect) and re-centers
  the book. Coin logos are bundled from the CC0
  [cryptocurrency-icons](https://github.com/spothq/cryptocurrency-icons) set.
- **Price grouping (`nSigFigs` / `mantissa`)** — a native menu that offers
  real tick sizes (1 / 2 / 5 / 10 / 100 / 1,000 for BTC) rather than raw
  significant figures, and shows the current one unlabelled, as trading UIs
  do. Steps are derived from the current price magnitude and mapped back to
  the `nSigFigs` (and `mantissa`, for the 2× and 5× steps) the feed expects,
  applied by re-subscribing.
- **True spread** — the spread row always shows the real market spread from
  the full-precision `bbo` stream, matching Hyperliquid: grouping is a
  display convenience and shouldn't inflate the apparent cost of crossing
  the book. Updates are sampled at most every 500 ms so the row doesn't
  strobe through re-quoting transients during fast markets.
- **Size units** — a toolbar toggle shows sizes and totals either in the coin
  (BTC/ETH) or in USDC notional; switching re-renders the stored snapshot
  without touching the subscription.
- **Header price** — the mark price comes from the `activeAssetCtx` channel,
  so it stays exact regardless of how coarsely the book is grouped (a mid
  derived from $1,000 buckets would be off by hundreds). It ticks with a
  numeric text transition and colors by direction.
- **Level inspector** — press and hold a row to open a native popover with
  what it would take to sweep the book down to that depth: distance from mid,
  average fill price, and cumulative size in coin and USDC. Keep dragging and
  the inspector follows the finger from level to level, with a selection
  haptic at each one. The inspector pins the depth — "the Nth level out from
  the spread" — so as the market moves the highlight stays on the same rung
  of the ladder and every figure updates live.
- **Change feedback** — cumulative depth bars animate as liquidity moves, and
  a row flashes in its side's color when something notable happens at that
  price: a genuinely new level, or its resting size at least doubling.
  Levels that merely scroll in past the far edge of the window don't flash, so
  the effect stays rare enough to mean something.
- **Haptics** — selection feedback when changing symbol, grouping, or units,
  and as the level inspector moves from row to row; muted from Settings.
- **Dynamic Type** — all text scales with the user's setting via
  `@ScaledMetric` (including the UIKit segmented control, which doesn't track
  it on its own), capped below the accessibility sizes where the book's three
  columns stop fitting side by side.
- **Resilience** — keep-alive pings every 45 s, automatic reconnection with
  exponential backoff, and the socket is torn down/restored as the app
  backgrounds/foregrounds.

## Architecture

```
Feed/
  Models              wire types for the frames we decode.
  HyperliquidSocket   websocket lifecycle: subscribe/unsubscribe (l2Book,
                      activeAssetCtx, and bbo per coin), pings, reconnection
                      with backoff. Emits decoded frames.
ViewModels/
  OrderbookViewModel  turns snapshots into fixed-identity row slots, coalesces
                      bursts to ≤10 UI applies/sec, pre-formats all strings.
  Preferences         settings that outlive a launch.
Screens/
  RootView            tab bar; owns the model and the feed's lifecycle, so
                      switching tabs never tears the socket down.
  OrderbookScreen     the book tab: header, book, toolbar.
  SettingsScreen      haptics toggle, feed and version info.
  MarketPickerSheet   searchable market list.
Components/
  MarketHeaderBar     market button and live mark price.
  OrderbookView       the book: scroll view anchored on the spread, plus the
                      press-and-scrub inspector.
  LevelRowView        one price level: columns, depth bar, flash.
  SpreadRowView       the divider showing the true spread.
  LevelStatsView      the inspector's popover contents.
  BookToolbar         grouping menu and unit toggle.
  PressAndScrub       UIKit long-press bridge that coexists with scrolling.
Design/
  Theme, Haptics      colors and feedback.
```

Performance notes:

- Row slots have **fixed identities** (`ask-0` … `bid-19`), so SwiftUI updates
  text in place instead of diffing inserted/removed rows — the book stays
  visually stable while prices move.
- Frames are **coalesced**: only the latest snapshot is applied, at most every
  100 ms, so bursts never queue up stale renders; spread updates from the
  chattier `bbo` stream are sampled at 500 ms.
- Rows whose content didn't change in a snapshot **skip re-rendering**
  entirely (`Equatable` views), and the depth bar is a trailing-anchored
  scale transform — no per-row `GeometryReader`, no layout pass on change.
- All number formatting happens once per snapshot in the view model, not in
  view bodies; digits are monospaced to avoid layout jitter.
- The level inspector is **one shared popover** anchored to the selected row,
  not forty per-row presentation modifiers, and its long-press recognizer is
  a single UIKit gesture that arbitrates cleanly with the scroll view's pan.
