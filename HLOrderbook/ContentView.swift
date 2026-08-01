import SwiftUI

struct ContentView: View {
    @ScaledMetric(relativeTo: .title) private var priceFontSize: CGFloat = 28
    @ScaledMetric(relativeTo: .headline) private var symbolFontSize: CGFloat = 19
    @ScaledMetric(relativeTo: .footnote) private var captionFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var chevronFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .headline) private var logoSize: CGFloat = 26

    @State private var model = OrderbookViewModel()
    @State private var showsMarketPicker = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 14) {
            header
                .padding(.horizontal, 16)
            OrderbookView(model: model)
                .padding(.horizontal, 12)
            toolbar
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showsMarketPicker) {
            MarketPickerSheet(model: model)
                .presentationDetents([.medium, .large])
        }
        .preferredColorScheme(.dark)
        .task { model.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.resume()
            case .background: model.suspend()
            default: break
            }
        }
    }

    // MARK: - Header

    /// Full-width bar: market selector on the left, live mid price on the
    /// right.
    private var header: some View {
        HStack(spacing: 8) {
            Button {
                showsMarketPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(model.coin.iconName)
                        .resizable()
                        .frame(width: logoSize, height: logoSize)
                        .clipShape(Circle())
                    Text(model.coin.rawValue)
                        .font(.system(size: symbolFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: chevronFontSize, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // One flat baseline-aligned row: nesting the arrow and price in
            // their own HStack would hand the outer row a centre-aligned
            // baseline that shifts whenever the arrow appears.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if model.priceDirection != .flat {
                    Image(systemName: model.priceDirection == .up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: captionFontSize))
                        .foregroundStyle(color(for: model.priceDirection))
                        // Centre the arrow on the digits instead of sitting it
                        // on their baseline: the price's cap-height centre is
                        // roughly 35% of its font size above it.
                        .alignmentGuide(.firstTextBaseline) {
                            $0[VerticalAlignment.center] + priceFontSize * 0.35
                        }
                }
                Text(model.priceText)
                    .font(.system(size: priceFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color(for: model.priceDirection))
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: model.priceText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("USDC")
                    .font(.system(size: captionFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
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

    private func color(for direction: OrderbookViewModel.Direction) -> Color {
        switch direction {
        case .up: Theme.bid
        case .down: Theme.ask
        case .flat: .primary
        }
    }

    private var toolbar: some View {
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

    /// Price grouping — the same `nSigFigs` control, surfaced as the spread
    /// it produces, which is what it actually does to the book.
    private var groupingMenu: some View {
        Menu {
            Picker("Spread", selection: $model.grouping) {
                ForEach(model.groupingOptions) { option in
                    Text(option.label).tag(option.grouping)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Spread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.card))
        }
        .tint(.primary)
    }

}

/// Market selection as a searchable sheet, so the same UI scales from the
/// assignment's two coins to a full asset list.
struct MarketPickerSheet: View {
    var model: OrderbookViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var coins: [OrderbookViewModel.Coin] {
        let all = OrderbookViewModel.Coin.allCases
        guard !query.isEmpty else { return all }
        return all.filter { $0.rawValue.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(coins) { coin in
                Button {
                    model.coin = coin
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(coin.iconName)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                        Text(coin.rawValue)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if coin == model.coin {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.bid)
                        }
                    }
                    // Without this the spacer between the name and the
                    // checkmark isn't part of the hit area.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .listSectionSpacing(.compact)
            .contentMargins(.top, 8, for: .scrollContent)
            .background(Theme.background)
            .navigationTitle("Markets")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search markets")
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
