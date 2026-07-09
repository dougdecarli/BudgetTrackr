import SwiftUI
import SwiftData

/// The emphasis piece of the Meses dashboard: the month's bottom-line
/// `Resultado` up top, the delta vs. the previous month, and the income /
/// spending split. Mirrors the math previously shown in `SummarySectionView`.
struct SummaryHeroCard: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    let month: Month

    private var totals: SummaryMath.Totals { SummaryMath.totals(for: month) }
    private var emDinheiro: Bool { settings.first?.emDinheiroEnabled ?? false }

    private var previousTotals: SummaryMath.Totals? {
        guard let prev = MonthRollover.previous(of: month, in: context) else { return nil }
        return SummaryMath.totals(for: prev)
    }

    private var income: Decimal { totals.income + totals.benefit }

    private var netDelta: Double? {
        guard let prev = previousTotals else { return nil }
        return SummaryMath.percentDelta(current: totals.netResult, previous: prev.netResult)
    }

    private var incomeDelta: Double? {
        guard let prev = previousTotals else { return nil }
        return SummaryMath.percentDelta(current: income, previous: prev.income + prev.benefit)
    }

    private var spendingDelta: Double? {
        guard let prev = previousTotals else { return nil }
        return SummaryMath.percentDelta(current: totals.spending, previous: prev.spending)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Resultado do mês")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let netDelta {
                    DeltaPill(value: netDelta)
                }
            }

            Text(Money.formatSigned(totals.netResult))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(totals.netResult < 0 ? Color.red : Color.green)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            SpendBar(income: income, spending: totals.spending)

            Divider()

            HStack(spacing: 0) {
                statColumn(title: "Renda", value: income,
                           icon: "arrow.down.left.circle.fill", tint: .green,
                           delta: incomeDelta, higherIsBetter: true)
                Divider().frame(height: 56)
                statColumn(title: "Gastos", value: totals.spending,
                           icon: "arrow.up.right.circle.fill", tint: .red,
                           delta: spendingDelta, higherIsBetter: false)
            }

            if totals.tax > 0 {
                detailRow("Impostos", Money.formatSigned(-totals.tax))
            }

            if emDinheiro {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Em dinheiro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    detailRow("Renda", totals.incomeEmDinheiro.brl)
                    detailRow("Gastos", Money.formatSigned(-totals.spendingEmDinheiro))
                    detailRow(
                        "Resultado",
                        Money.formatSigned(totals.netResultEmDinheiro),
                        emphasis: true,
                        valueColor: totals.netResultEmDinheiro < 0 ? .red : .green
                    )
                }
            }

            if previousTotals == nil {
                Text("Sem mês anterior para comparar.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func statColumn(
        title: LocalizedStringKey,
        value: Decimal,
        icon: String,
        tint: Color,
        delta: Double?,
        higherIsBetter: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.brl)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let delta {
                    DeltaPill(value: delta, higherIsBetter: higherIsBetter)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private func detailRow(
        _ label: LocalizedStringKey,
        _ value: String,
        emphasis: Bool = false,
        valueColor: Color? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(emphasis ? .semibold : .regular)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(emphasis ? .semibold : .regular)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
    }
}

/// Small capsule showing a signed percentage change with a directional arrow.
/// The tint reflects whether the change is favorable (e.g. rising spending is bad).
/// Shared with the month's expenses detail sheet so category deltas read the same
/// as the dashboard's income/spending/result deltas.
struct DeltaPill: View {
    let value: Double
    var higherIsBetter: Bool = true

    var body: some View {
        let up = value >= 0
        let favorable = higherIsBetter ? up : !up
        let tint: Color = favorable ? .green : .red
        return HStack(spacing: 3) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(Money.formatPercent(abs(value)))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
    }
}
