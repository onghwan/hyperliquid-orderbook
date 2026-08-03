import SwiftUI

/// Bottom bar: price grouping on the left, size unit on the right — plus the
/// spread in the middle where there's width for it, since the side-by-side
/// book has no spread row of its own.
struct BookToolbar: View {
    @Bindable var model: OrderbookViewModel
    var isWide = false
    /// The bottom safe area, which the wide bar cancels out for itself.
    var bottomInset: CGFloat = 0

    @ScaledMetric(relativeTo: .caption2) private var chevronFontSize: CGFloat = 10
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSettings = false

    /// Matches the header bar, so the two line up down both edges.
    private let sideMargin: CGFloat = 12
    private let cornerRadius: CGFloat = 26

    var body: some View {
        HStack {
            groupingMenu

            Spacer()

            HStack(spacing: 8) {
                unitMenu
                settingsButton
            }
        }
        // Overlaid rather than placed between the controls, so it's centred
        // on the bar itself and not on whatever space they leave. The bar's
        // height doesn't change with what sits here, so the book never moves.
        .overlay {
            if model.isStale {
                // Takes the spread's place when there is one: a spread from a
                // dead connection is as stale as the rest of the book.
                reconnecting
            } else if isWide {
                spread
            }
        }
        // A glass bar the book scrolls beneath: edge to edge in portrait,
        // a rounded island matching the header's width in landscape.
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.clear
                .glassBackground(cornerRadius: isWide ? cornerRadius : 0)
                .ignoresSafeArea(edges: isWide ? [] : .bottom)
                // The glass layer keeps the appearance it was built with, so
                // switching themes needs it rebuilt rather than redrawn.
                .id(colorScheme)
            )
        .padding(.horizontal, isWide ? sideMargin : 0)
        // Cancelled by hand: `ignoresSafeArea` has no effect on a view that is
        // itself a safe-area inset.
        .padding(.bottom, isWide ? -bottomInset : 0)
        .sheet(isPresented: $showsSettings) {
            SettingsScreen()
                .presentationDetents([.large])
        }
    }

    private var reconnecting: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
            Text("Reconnecting")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .allowsHitTesting(false)
    }

    private var spread: some View {
        HStack(spacing: 14) {
            Text("Spread")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(model.spreadText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(model.spreadPercentText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .allowsHitTesting(false)
    }

    /// Price grouping — the `nSigFigs` control, labelled by the tick size it
    /// produces rather than by the parameter behind it.
    private var groupingMenu: some View {
        Menu {
            Picker("Price grouping", selection: $model.grouping) {
                ForEach(model.groupingOptions) { option in
                    Text(option.label).tag(option.grouping)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.groupingLabel)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                // Points the way the menu opens.
                Image(systemName: "chevron.up")
                    .font(.system(size: chevronFontSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .tint(.primary)
        .accessibilityLabel("Price grouping")
    }
    
    private var unitMenu: some View {
        Menu {
            Picker("Unit", selection: $model.sizeUnit) {
                Text(model.coin.rawValue).tag(OrderbookViewModel.SizeUnit.coin)
                Text("USDC").tag(OrderbookViewModel.SizeUnit.usdc)
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.unitLabel)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                // Points the way the menu opens.
                Image(systemName: "chevron.up")
                    .font(.system(size: chevronFontSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .tint(.primary)
        .accessibilityLabel("Unit")
    }
    
    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .tint(.primary)
        .accessibilityLabel("Settings")
    }
}
