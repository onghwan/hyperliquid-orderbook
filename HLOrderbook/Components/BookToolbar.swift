import SwiftUI

/// Bottom bar: price grouping on the left, size unit on the right.
struct BookToolbar: View {
    @Bindable var model: OrderbookViewModel

    @ScaledMetric(relativeTo: .caption2) private var chevronFontSize: CGFloat = 10
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack {
            groupingMenu

            Spacer()

            Picker("Unit", selection: $model.sizeUnit) {
                Text(model.coin.rawValue).tag(OrderbookViewModel.SizeUnit.coin)
                Text("USDC").tag(OrderbookViewModel.SizeUnit.usdc)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            // UISegmentedControl ignores SwiftUI fonts and doesn't track
            // Dynamic Type on its own, so its titles are scaled by hand
            // whenever the setting changes.
            .onAppear { scaleSegmentedTitles() }
            .onChange(of: dynamicTypeSize) { scaleSegmentedTitles() }
            // The appearance proxy only affects controls created afterwards,
            // so rebuild this one when the setting changes.
            .id(dynamicTypeSize)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    /// Price grouping — the same `nSigFigs` control, labelled by the tick it
    /// produces. The tick alone is label enough for anyone reading a book,
    /// and it keeps the word "spread" for the real one in the book itself.
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
                // Mirrors the market button's chevron, pointing the way this
                // menu opens.
                Image(systemName: "chevron.up")
                    .font(.system(size: chevronFontSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.card))
        }
        .tint(.primary)
        .accessibilityLabel("Price grouping")
    }

    /// Feeds the segmented control a font scaled for the current text size,
    /// clamped by the app-wide Dynamic Type cap like everything else.
    private func scaleSegmentedTitles() {
        let base = UIFont.systemFont(ofSize: 13, weight: .medium)
        let traits = UITraitCollection(preferredContentSizeCategory: Self.sizeCategory(for: dynamicTypeSize))
        let scaled = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: base, compatibleWith: traits)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: scaled], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: scaled], for: .selected)
    }

    private static func sizeCategory(for size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
