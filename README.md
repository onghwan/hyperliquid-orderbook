# HLOrderbook

A native iOS orderbook widget streaming the live L2 book from Hyperliquid's
websocket feed, built with Swift/SwiftUI only — no third-party dependencies.

<p>
  <em>BTC/ETH · live depth · price grouping (nSigFigs) · haptics</em>
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
- **Spread / price grouping (`nSigFigs` / `mantissa`)** — a native menu that
  offers real tick sizes (1 / 2 / 5 / 10 / 100 / 1,000 for BTC) rather than raw
  significant figures, labelled by the spread each one produces. Steps are
  derived from the current price magnitude and mapped back to the `nSigFigs`
  (and `mantissa`, for the 2× and 5× steps) the feed expects, applied by
  re-subscribing.
- **Size units** — a toolbar toggle shows sizes and totals either in the coin
  (BTC/ETH) or in USDC notional; switching re-renders the stored snapshot
  without touching the subscription.
- **Header price** — the mark price comes from the `activeAssetCtx` channel,
  so it stays exact regardless of how coarsely the book is grouped (a mid
  derived from $1,000 buckets would be off by hundreds). It ticks with a
  numeric text transition and colors by direction.
- **Change feedback** — cumulative depth bars animate as liquidity moves.
- **Haptics** — selection feedback when changing symbol, grouping, or units;
  a light impact when tapping a row to copy its price.
- **Resilience** — keep-alive pings every 45 s, automatic reconnection with
  exponential backoff, and the socket is torn down/restored as the app
  backgrounds/foregrounds.

## Architecture

```
HyperliquidSocket   websocket lifecycle: subscribe/unsubscribe (l2Book +
                    activeAssetCtx per coin), pings, reconnection with
                    backoff. Emits decoded frames.
OrderbookViewModel  turns snapshots into fixed-identity row slots, coalesces
                    bursts to ≤10 UI applies/sec, pre-formats all strings.
OrderbookView       the book: scroll view anchored on the spread, depth bars.
ContentView         header bar (market picker, live mid price), bottom toolbar
                    (grouping menu, unit toggle), and the copy toast.
```

Performance notes:

- Row slots have **fixed identities** (`ask-0` … `bid-19`), so SwiftUI updates
  text in place instead of diffing inserted/removed rows — the book stays
  visually stable while prices move.
- Frames are **coalesced**: only the latest snapshot is applied, at most every
  100 ms, so bursts never queue up stale renders.
- All number formatting happens once per snapshot in the view model, not in
  view bodies; digits are monospaced to avoid layout jitter.
