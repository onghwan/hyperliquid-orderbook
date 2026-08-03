# HLOrderbook

A native iOS order book that streams live data from Hyperliquid's websocket.
Written in Swift and SwiftUI only, with no third-party libraries.

<p>
  <img src="docs/screenshot.png" width="300" alt="HLOrderbook — live BTC book" />
</p>
<p>
  <img src="docs/screenshot-landscape.png" width="612" alt="HLOrderbook — two-column landscape layout" />
</p>
<p>
  <em>BTC/ETH · live depth · price grouping (nSigFigs/mantissa) · level
  inspector · two-column landscape · light &amp; dark · haptics · Dynamic
  Type</em>
</p>

## Features

- **Live L2 book** — Asks on top, bids below, spread in the middle. The list
  scrolls under the floating glass header and toolbar. Nothing is drawn until
  the first snapshot arrives. Until then a spinner sits where the price goes.
- **Unfolding** — When a book arrives, the rows open outward from the spread.
  The closest row moves first, and each row fades in as it moves. Switching
  market folds the old book back the same way. This only changes `offset` and
  `opacity`, so SwiftUI does not run a layout pass and the rows keep their
  identities.
- **Two-column landscape** — When the screen is wider than 600 pt, bids and
  asks are shown side by side. Prices meet in the middle and the depth bars
  grow outward, so twice as many levels fit. The app checks width, not
  orientation, so iPads use this layout in both orientations.
- **Symbol selection** — Choose BTC or ETH from a searchable sheet. Adding
  more markets takes one more enum case. Switching sends a new subscription on
  the same socket, and the app remembers your choice for the next launch.
- **Price grouping (`nSigFigs` / `mantissa`)** — The menu shows real tick
  sizes (1, 2, 5, 10, 100, 1000 for BTC) instead of raw significant figures.
  The app works out these steps from the current price, then converts them
  back to the values the feed expects.
- **Size units** — Show size and total in the coin or in USDC. Switching
  re-formats the snapshot the app already has and does not change the
  subscription.
- **Level inspector** — Press and hold a row to see what it would cost to buy
  or sell up to that level: distance from the mid price, average fill price,
  and total size. Drag your finger and the popover follows, with a haptic at
  each level. It tracks the level's depth, such as "the 5th row from the
  spread", not its price. So it stays on the same row as the market moves.
- **Change feedback** — Depth bars animate when sizes change. A row flashes
  when the level is new, or when its size at least doubles. Rows that only
  scroll into view do not flash, so a flash always means something changed.
- **Light and dark** — Choose in Settings. The choice is saved. Every color
  is in the asset catalog with a light and a dark value.
- **Haptics and Dynamic Type** — Every control gives haptic feedback, and so
  does the inspector as it moves between rows. You can turn this off in
  Settings. Text and row heights follow the user's text size through
  `@ScaledMetric`, up to a limit where the three columns stop fitting.
- **Resilience** — The app pings every 45 seconds and reconnects with
  exponential backoff. It closes the socket when the app goes to the
  background and opens it again when the app returns.
- **Stale prices are marked** — A first connection takes a moment and the
  spinner already covers that, so nothing extra is shown. But once a
  connection drops, the numbers on screen are the last ones that arrived, not
  the market now. The toolbar says "Reconnecting" and the header price dims
  until frames come back.

## The feed

The app subscribes to three channels on one socket to
`wss://api.hyperliquid.xyz/ws`. It needs all three because of grouping. Once
the exchange groups the book into buckets, the book can no longer show you the
exact prices around it.

| Channel | Carries | Drives |
| --- | --- | --- |
| `l2Book` | depth snapshots at the requested bucket size | the twenty levels on each side |
| `activeAssetCtx` | the asset's mark price | the header price |
| `bbo` | best bid and ask at full precision | the spread readout |

**`l2Book`** is the only channel that takes `nSigFigs` and `mantissa`. The
exchange does the grouping, so changing the tick size means sending a new
subscription instead of adding up levels in the app. Every message is a full
snapshot, so there is no local book that can fall out of sync.

**`activeAssetCtx`** gives the exchange's own mark price. If the app worked
out a mid price from the book instead, that price would only be as exact as
the buckets. With $1,000 buckets it could be off by hundreds, and it would
change every time you changed the grouping.

**`bbo`** solves the same problem for the spread. With $1,000 grouping, the
closest bid and ask are $1,000 apart, so the spread would look about 100 times
larger than it really is. This channel reports the real best bid and ask. It
updates more often than the other two, so the app reads it at most every
500 ms. Any faster and the number changes too quickly to read.

Switching market resubscribes to all three channels. Changing grouping
resubscribes to `l2Book` only.

## Architecture

```
RootView              owns the view model and the feed's lifecycle, then
                      hands off to the screen.
Book/
  PriceGrid           the arithmetic between Hyperliquid's significant-figure
                      grouping and the tick sizes the UI shows.
  BookChanges         what moved since the last render, and which of those
                      moves is worth flashing a row for.
Feed/
  Models              the types we decode the frames into.
  HyperliquidSocket   the websocket: subscribe and unsubscribe (l2Book,
                      activeAssetCtx, and bbo per coin), pings, and
                      reconnection with backoff. Sends out decoded frames.
ViewModels/
  OrderbookViewModel  turns snapshots into fixed row slots, groups bursts into
                      at most 10 UI updates per second, formats every string
                      once, and remembers the selected market.
Screens/
  OrderbookScreen     places the header, book, and toolbar, and picks the
                      ladder or the two-column layout by width.
  SettingsScreen      appearance, haptics, and feed info. Shown as a sheet.
  MarketPickerScreen  searchable market list. Shown as a sheet.
Components/
  MarketHeaderBar     market button and live mark price, on glass.
  OrderbookView       the book itself: ladder or columns, plus the
                      press-and-drag inspector.
  LevelRowView        one price level. Its column order and bar direction
                      change with the layout.
  BookColumnHeader    column titles, mirrored for the right-hand column.
  SpreadRowView       the divider in the middle showing the true spread.
  LevelStatsView      what the inspector's popover shows.
  BookToolbar         grouping menu, unit menu, settings, and the spread in
                      the middle when the layout is wide.
  PressAndScrub       a UIKit long press that works alongside scrolling.
Design/
  Theme               colors, from the asset catalog (light and dark).
  Haptics             prepared feedback with a global mute.
  GlassBackground     Liquid Glass on iOS 26, a material fallback below that.
  Preferences         which of those the user picked, saved across launches.
                      The app owns it and passes it down the environment.
```

## Tests

`HLOrderbookTests` covers the logic that does not need a socket, using Swift
Testing. Run it with `⌘U`, or:

```
xcodebuild test -scheme HLOrderbook -destination 'platform=iOS Simulator,name=iPhone 17'
```

The three suites are `PriceGrid` (tick sizes and header precision at real BTC
and ETH magnitudes), `BookChanges` (when a row flashes and, mostly, when it
does not), and `OrderbookViewModel` (what it restores at launch, what it
saves, and what the toolbar reads off it).

## Performance

- **Fixed row slots.** Each row keeps the same identity for its whole life
  (`ask-0` … `bid-19`). SwiftUI updates the text inside a row instead of
  inserting and removing rows, so the book does not jump while prices move.
- **Rows that did not change do not redraw.** `LevelRowView` is `Equatable`,
  so SwiftUI skips its body when the data is the same. The depth bar is a
  scale transform anchored to one edge, so changing it does not run a layout
  pass and each row does not need its own `GeometryReader`.
- **Numbers are formatted once.** The view model formats every string when a
  snapshot arrives, not inside view bodies. Digits are monospaced so the
  columns do not shift as values change.
- **One popover, one gesture.** The level inspector is a single popover
  anchored to the selected row, not forty presentation modifiers. Its long
  press is one UIKit gesture recognizer, which lets the scroll view keep its
  own pan.

Coin logos come from the CC0
[cryptocurrency-icons](https://github.com/spothq/cryptocurrency-icons) set.
