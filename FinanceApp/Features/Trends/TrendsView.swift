import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query(sort: [SortDescriptor(\Month.anchorDate)]) private var months: [Month]

    @State private var window: TrendsWindow = .last6

    /// Trends focus on completed months, so the in-progress current month is
    /// excluded — when it's June, the most recent month shown is May.
    private var completedMonths: [Month] {
        let currentAnchor = Date().monthAnchor
        return months.filter { $0.anchorDate < currentAnchor }
    }

    private var windowMonths: [Month] {
        Array(completedMonths.suffix(window.count))
    }

    private var points: [TrendPoint] {
        windowMonths.map { month in
            let t = SummaryMath.totals(for: month)
            return TrendPoint(
                anchor: month.anchorDate,
                income: t.income + t.benefit,
                spending: t.spending,
                net: t.netResult
            )
        }
    }

    private var hasData: Bool {
        points.contains { $0.income != 0 || $0.spending != 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Janela", selection: $window) {
                    ForEach(TrendsWindow.allCases) { window in
                        Text(window.label).tag(window)
                    }
                }
                .pickerStyle(.segmented)

                if !hasData {
                    ContentUnavailableView(
                        "Sem dados ainda",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Registre rendas e gastos nos seus meses para acompanhar suas tendências aqui.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    StatSummaryRow(points: points)
                    IncomeVsSpendingCard(points: points)
                    NetResultCard(points: points)
                    CategorySpendingCard(
                        months: windowMonths,
                        windowCount: window.count
                    )
                    YTDCard(months: completedMonths)
                    MonthComparisonCard(months: completedMonths)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Tendências")
    }
}

enum TrendsWindow: String, CaseIterable, Identifiable {
    case last3
    case last6
    case last12

    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .last3:  return "3 meses"
        case .last6:  return "6 meses"
        case .last12: return "12 meses"
        }
    }
    var count: Int {
        switch self {
        case .last3:  return 3
        case .last6:  return 6
        case .last12: return 12
        }
    }
}

struct TrendPoint: Identifiable {
    var id: Date { anchor }
    let anchor: Date
    let income: Decimal
    let spending: Decimal
    let net: Decimal
}

// MARK: - Card container

/// Rounded card matching the Meses dashboard, with an optional title.
private struct Card<Content: View>: View {
    let title: LocalizedStringKey?
    let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Stat tiles (window totals)

private struct StatSummaryRow: View {
    let points: [TrendPoint]

    private var totalIncome: Decimal { points.reduce(0) { $0 + $1.income } }
    private var totalSpending: Decimal { points.reduce(0) { $0 + $1.spending } }
    private var totalNet: Decimal { points.reduce(0) { $0 + $1.net } }
    private var monthCount: Int { max(points.count, 1) }

    var body: some View {
        HStack(spacing: 12) {
            tile("Renda", totalIncome, tint: .green, icon: "arrow.down.left")
            tile("Gastos", totalSpending, tint: .red, icon: "arrow.up.right")
            tile("Resultado", totalNet, tint: totalNet < 0 ? .red : .green, icon: "equal.circle")
        }
    }

    private func tile(_ label: LocalizedStringKey, _ value: Decimal, tint: Color, icon: String) -> some View {
        let average = value / Decimal(monthCount)
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.brl)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("Média \(average.brl)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Renda vs. gastos (grouped bars, tap to inspect)

private struct IncomeVsSpendingCard: View {
    let points: [TrendPoint]
    @State private var selectedDate: Date?

    private var selected: TrendPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.anchor.timeIntervalSince(selectedDate)) < abs($1.anchor.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Card("Renda vs. gastos") {
            header
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Mês", point.anchor, unit: .month),
                        y: .value("Valor", point.income.chartDouble)
                    )
                    .foregroundStyle(by: .value("Série", "Renda"))
                    .position(by: .value("Série", "Renda"))
                    .cornerRadius(4)

                    BarMark(
                        x: .value("Mês", point.anchor, unit: .month),
                        y: .value("Valor", point.spending.chartDouble)
                    )
                    .foregroundStyle(by: .value("Série", "Gastos"))
                    .position(by: .value("Série", "Gastos"))
                    .cornerRadius(4)
                }

                if let selected {
                    RuleMark(x: .value("Mês", selected.anchor, unit: .month))
                        .foregroundStyle(Color.gray.opacity(0.25))
                        .zIndex(-1)
                }
            }
            .chartForegroundStyleScale(["Renda": Color.green, "Gastos": Color.red])
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(compactMoney(v))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                }
            }
            .frame(height: 200)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let selected {
            HStack(spacing: 12) {
                Text(selected.anchor.shortMonthLabelPtBR)
                    .font(.caption.weight(.semibold))
                Spacer()
                valueChip(selected.income, tint: .green)
                valueChip(selected.spending, tint: .red)
            }
        } else {
            HStack(spacing: 16) {
                legend(.green, "Renda")
                legend(.red, "Gastos")
                Spacer()
            }
        }
    }

    private func legend(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func valueChip(_ value: Decimal, tint: Color) -> some View {
        Text(value.brl)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
    }
}

// MARK: - Resultado mensal (area + line)

private struct NetResultCard: View {
    let points: [TrendPoint]

    var body: some View {
        Card("Resultado mensal") {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Mês", point.anchor, unit: .month),
                        y: .value("Resultado", point.net.chartDouble)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Mês", point.anchor, unit: .month),
                        y: .value("Resultado", point.net.chartDouble)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
                    .symbol(.circle)
                    .symbolSize(28)
                }

                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(compactMoney(v))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                }
            }
            .frame(height: 180)
        }
    }
}

// MARK: - Gastos por categoria (horizontal bars)

private struct CategorySpendingCard: View {
    let months: [Month]
    let windowCount: Int

    private var slices: [SpendingSlice] {
        var buckets: [UUID: (Category, Decimal)] = [:]
        for month in months {
            for (cat, amount) in SummaryMath.categoryBreakdown(for: month) {
                buckets[cat.id, default: (cat, 0)].1 += amount
            }
        }
        let breakdown = buckets.values
            .map { (category: $0.0, amount: $0.1) }
            .sorted { $0.amount > $1.amount }
        return SpendingDonut.slices(from: breakdown)
    }

    var body: some View {
        Card("Gastos por categoria · \(windowCount) meses") {
            if slices.isEmpty {
                Text("Sem gastos no período.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                SpendingDonutView(slices: slices)
            }
        }
    }
}

// MARK: - Acumulado no ano (YTD + savings rate)

private struct YTDCard: View {
    let months: [Month]

    private var ytd: SummaryMath.Totals {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var sum = SummaryMath.Totals()
        for month in months where calendar.component(.year, from: month.anchorDate) == year {
            let t = SummaryMath.totals(for: month)
            sum.income += t.income
            sum.benefit += t.benefit
            sum.tax += t.tax
            sum.recurring += t.recurring
            sum.oneOff += t.oneOff
            sum.invoice += t.invoice
            sum.ticketCardSpend += t.ticketCardSpend
        }
        return sum
    }

    private var savingsRate: Double {
        let income = ytd.income + ytd.benefit
        guard income > 0 else { return 0 }
        return max(0, min(1, (ytd.netResult / income).chartDouble))
    }

    var body: some View {
        let t = ytd
        Card("Acumulado no ano") {
            VStack(spacing: 8) {
                row("Renda", t.income + t.benefit)
                row("Gastos", -t.spending)
                row("Resultado", t.netResult, emphasis: true,
                    tint: t.netResult < 0 ? .red : .green)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Taxa de poupança")
                        .font(.subheadline)
                    Spacer()
                    Text(Money.formatPercent(savingsRate, fractionDigits: 0))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(savingsRate > 0 ? .green : .secondary)
                }
                ProgressView(value: savingsRate)
                    .tint(.green)
            }
        }
    }

    @ViewBuilder
    private func row(_ label: LocalizedStringKey, _ value: Decimal, emphasis: Bool = false, tint: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(emphasis ? .semibold : .regular)
            Spacer()
            Text(Money.formatSigned(value))
                .font(.subheadline)
                .monospacedDigit()
                .fontWeight(emphasis ? .semibold : .regular)
                .foregroundStyle(tint ?? .primary)
        }
    }
}

// MARK: - Comparação mês a mês

private struct MonthComparisonCard: View {
    let months: [Month]

    var body: some View {
        Card("Comparação mês a mês") {
            let recent = Array(months.suffix(2))
            if recent.count < 2 {
                Text("É preciso ter pelo menos dois meses para comparar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                let prev = SummaryMath.totals(for: recent[0])
                let cur = SummaryMath.totals(for: recent[1])

                HStack {
                    Spacer()
                    Text("\(recent[0].anchorDate.shortMonthLabelPtBR) → \(recent[1].anchorDate.shortMonthLabelPtBR)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                metricRow("Renda", cur: cur.income + cur.benefit, prev: prev.income + prev.benefit,
                          higherIsBetter: true) { $0.brl }
                metricRow("Gastos", cur: cur.spending, prev: prev.spending,
                          higherIsBetter: false) { Money.formatSigned(-$0) }
                metricRow("Resultado", cur: cur.netResult, prev: prev.netResult,
                          higherIsBetter: true, emphasis: true) { Money.formatSigned($0) }
            }
        }
    }

    @ViewBuilder
    private func metricRow(
        _ label: LocalizedStringKey,
        cur: Decimal,
        prev: Decimal,
        higherIsBetter: Bool,
        emphasis: Bool = false,
        display: (Decimal) -> String
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(emphasis ? .semibold : .regular)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(display(cur))
                    .font(.subheadline)
                    .monospacedDigit()
                    .fontWeight(emphasis ? .semibold : .regular)
                Text("de \(display(prev))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            DeltaBadge(
                delta: SummaryMath.percentDelta(current: cur, previous: prev),
                higherIsBetter: higherIsBetter
            )
            .frame(width: 66, alignment: .trailing)
        }
    }
}

/// Percentage-change capsule, tinted by whether the change is favorable.
private struct DeltaBadge: View {
    let delta: Double?
    let higherIsBetter: Bool

    var body: some View {
        if let delta {
            let favorable = higherIsBetter ? delta >= 0 : delta <= 0
            let tint: Color = favorable ? .green : .red
            HStack(spacing: 2) {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(Money.formatPercent(abs(delta), fractionDigits: 0))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

private extension Decimal {
    var chartDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}

/// Compact currency for axis labels, e.g. "R$ 2,5k" / "$2.5k". Symbol and
/// grouping follow the app's presentation currency.
private func compactMoney(_ value: Double) -> String {
    let symbol = Money.usesEnglish ? "$" : "R$ "
    let magnitude = abs(value)
    if magnitude >= 1000 {
        let k = value / 1000
        let digits = magnitude >= 10_000 ? 0 : 1
        return "\(symbol)\(k.formatted(.number.precision(.fractionLength(digits)).locale(Money.presentationLocale)))k"
    }
    return value.formatted(.number.precision(.fractionLength(0)).locale(Money.presentationLocale))
}
