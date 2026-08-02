import SwiftUI

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
