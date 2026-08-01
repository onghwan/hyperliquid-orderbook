import SwiftUI

struct ContentView: View {
    @State private var model = OrderbookViewModel()
    @State private var showsMarketPicker = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 14) {
            header
                .padding(.horizontal, 16)
            OrderbookView(model: model, onCopyPrice: copy(price:))
                .padding(.horizontal, 12)
            toolbar
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) { toastView }
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
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(model.coin.rawValue)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Text("USDC")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                if model.midDirection != .flat {
                    Image(systemName: model.midDirection == .up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 13))
                }
                Text(model.midText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: model.midText)
            }
            .foregroundStyle(midColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }

    private var midColor: Color {
        switch model.midDirection {
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.card))
        }
        .tint(.primary)
    }

    // MARK: - Copy toast

    private func copy(price: String) {
        UIPasteboard.general.string = price
        Haptics.lightTap()
        toastTask?.cancel()
        withAnimation(.snappy) { toast = "Copied \(price)" }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { toast = nil }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.card))
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
                        Text("/ USDC")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if coin == model.coin {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.bid)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
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
