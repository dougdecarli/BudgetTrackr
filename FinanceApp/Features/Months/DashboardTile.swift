import SwiftUI

/// Compact tile used in the Meses dashboard's 2×2 grid. Replaces the former
/// full-width `DashboardCard` rows so the four destinations sit above the fold
/// alongside the category breakdown. Same data, same tap-to-push behavior.
struct DashboardTile: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// `nil` renders `placeholder` (in the accent color) instead of a value.
    let amount: Decimal?
    var amountColor: Color = .primary
    var placeholder: LocalizedStringKey = "—"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2, reservesSpace: true)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Group {
                    if let amount {
                        Text(amount.brl).foregroundStyle(amountColor)
                    } else {
                        Text(placeholder).foregroundStyle(Color.accentColor)
                    }
                }
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
