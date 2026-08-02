import SwiftUI

/// The divider between the two sides, showing the true market spread.
struct SpreadRowView: View {
    let spreadText: String
    let percentText: String

    var body: some View {
        HStack(spacing: 18) {
            Text("Spread")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(spreadText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(percentText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
    }
}
