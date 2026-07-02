import SwiftUI

/// Tappable summary row used on the Meses dashboard. Shows an icon, a title,
/// a count subtitle, and the domain's total — tapping opens its detail sheet.
struct DashboardCard: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// `nil` renders `placeholder` in the trailing slot instead of a value.
    let amount: Decimal?
    var amountColor: Color = .primary
    var placeholder: LocalizedStringKey = "—"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Group {
                    if let amount {
                        Text(amount.brl)
                            .foregroundStyle(amountColor)
                    } else {
                        Text(placeholder)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
