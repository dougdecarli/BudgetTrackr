import SwiftUI

/// Per-category spending breakdown for a single invoice, shown at the top of the
/// review screen. Each row is a tinted category icon, the name, a bar sized
/// relative to the largest category, and the amount.
struct InvoiceBreakdownCard: View {
    /// Categories with their invoice total, sorted descending by amount.
    let rows: [(category: Category, amount: Decimal)]
    /// When set, each row becomes tappable to drill into that category's
    /// invoice transactions.
    var onSelect: ((Category) -> Void)? = nil

    private var maxAmount: Decimal {
        rows.map(\.amount).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Gastos por categoria")
                .font(.headline)

            VStack(spacing: 18) {
                ForEach(rows, id: \.category.id) { row in
                    let content = InvoiceBreakdownRow(
                        category: row.category,
                        amount: row.amount,
                        fraction: fraction(for: row.amount),
                        showsChevron: onSelect != nil
                    )
                    if let onSelect {
                        Button { onSelect(row.category) } label: { content }
                            .buttonStyle(.plain)
                    } else {
                        content
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func fraction(for amount: Decimal) -> Double {
        guard maxAmount > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: amount / maxAmount).doubleValue
        return min(max(value, 0), 1)
    }
}

private struct InvoiceBreakdownRow: View {
    let category: Category
    let amount: Decimal
    let fraction: Double
    var showsChevron: Bool = false

    private var tint: Color { Theme.tint(for: category.id) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.15))
                Image(systemName: CategoryIcon.symbol(for: category.name))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CategoryNameText(category.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(amount.brl)
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                bar
            }
        }
        .contentShape(Rectangle())
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule().fill(tint)
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
    }
}
