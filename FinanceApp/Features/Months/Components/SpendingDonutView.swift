import SwiftUI
import Charts

/// One slice of the spending donut: a category (or the aggregated "Outros"),
/// its amount, and the color it shares with its chip elsewhere.
struct SpendingSlice: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let color: Color

    var value: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

enum SpendingDonut {
    /// Stable id for the aggregated "Outros" slice (not a real category).
    static let outrosID = UUID()

    /// Builds slices from a category breakdown, folding everything past the top
    /// N into a single gray "Outros" slice (only when it represents 2+).
    static func slices(from breakdown: [(category: Category, amount: Decimal)], top: Int = 5) -> [SpendingSlice] {
        guard !breakdown.isEmpty else { return [] }

        func slice(_ item: (category: Category, amount: Decimal)) -> SpendingSlice {
            // Store the raw name/key; the legend localizes it at display time.
            SpendingSlice(
                id: item.category.id,
                name: item.category.name.isEmpty ? "Sem categoria" : item.category.name,
                amount: item.amount,
                color: Theme.tint(for: item.category.id)
            )
        }

        guard breakdown.count > top + 1 else { return breakdown.map(slice) }

        let head = breakdown.prefix(top).map(slice)
        let restSum = breakdown.dropFirst(top).reduce(Decimal(0)) { $0 + $1.amount }
        return head + [
            SpendingSlice(id: outrosID, name: "Outros", amount: restSum, color: .gray)
        ]
    }
}

/// Donut chart + legend showing how spending splits across categories. The
/// total sits inside the ring; each legend row fits on one line using compact
/// "k" amounts so category names stay visible. Shared by the Meses dashboard
/// and the Trends "Gastos por categoria" card.
struct SpendingDonutView: View {
    @Environment(\.locale) private var locale
    let slices: [SpendingSlice]

    private var total: Decimal { slices.reduce(0) { $0 + $1.amount } }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            donut
            legend
        }
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Valor", slice.value),
                innerRadius: .ratio(0.68),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(slice.color)
        }
        .chartLegend(.hidden)
        .frame(width: 130, height: 130)
        .overlay {
            VStack(spacing: 1) {
                Text("Total")
                    .font(.system(size: 10, weight: .regular))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(total.brl)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 82)
        }
        .accessibilityLabel("Para onde foi")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 9, height: 9)
                    Text(CategoryLocalization.display(slice.name, locale: locale))
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(Money.compact(slice.amount))
                        .font(.subheadline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                    Text(share(slice.amount))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 30, alignment: .trailing)
                        .layoutPriority(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func share(_ amount: Decimal) -> String {
        guard total > 0 else { return "" }
        let ratio = NSDecimalNumber(decimal: amount / total).doubleValue
        return Money.formatPercent(ratio, fractionDigits: 0)
    }
}
