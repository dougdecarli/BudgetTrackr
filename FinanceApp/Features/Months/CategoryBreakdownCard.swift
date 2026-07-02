import SwiftUI

/// Shows where the month's money went: the top spending categories with
/// proportion bars. Reuses `SummaryMath.categoryBreakdown`. Renders nothing
/// when there's no spending yet.
struct CategoryBreakdownCard: View {
    let month: Month

    private var breakdown: [(category: Category, amount: Decimal)] {
        SummaryMath.categoryBreakdown(for: month)
    }

    var body: some View {
        if !breakdown.isEmpty {
            let top = Array(breakdown.prefix(5))
            let maxAmount = top.map(\.amount).max() ?? 1
            VStack(alignment: .leading, spacing: 14) {
                Text("Para onde foi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(top, id: \.category.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.category.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(item.amount.brl)
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: fraction(item.amount, of: maxAmount))
                            .tint(.accentColor)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func fraction(_ value: Decimal, of max: Decimal) -> Double {
        guard max > 0 else { return 0 }
        return NSDecimalNumber(decimal: value / max).doubleValue
    }
}
