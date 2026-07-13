import SwiftUI
import Charts

/// Drill-down behind the month's "Para onde foi" donut: every categorized
/// expense, grouped by category. A big donut of the month's total sits in the
/// header; each category is a section below with its total in the header and
/// the individual lines — recurring, avulsa or fatura — beneath.
struct MonthExpensesDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let groups: [SummaryMath.ExpenseGroup]
    /// Previous month's spend per category id, or `nil` when there's no earlier
    /// month. Drives the month-over-month variation badges.
    var previousTotals: [UUID: Decimal]? = nil
    /// The month being shown, used to name the comparison month in the header
    /// donut's "vs. maio" caption. `nil` hides that caption.
    var monthAnchor: Date? = nil

    private var total: Decimal {
        groups.reduce(0) { $0 + $1.amount }
    }

    private var previousTotal: Decimal? {
        previousTotals.map { $0.values.reduce(0, +) }
    }

    /// Slices for the header donut — one per category, sharing each category's
    /// chip color, largest first (groups are already sorted by amount).
    private var slices: [SpendingSlice] {
        SpendingDonut.slices(from: groups.map { (category: $0.category, amount: $0.amount) })
    }

    /// Overall spend change vs. the previous month. `nil` when there's no
    /// comparison month (or it had zero spend, leaving the delta undefined).
    private var overallDelta: Double? {
        guard let previousTotal else { return nil }
        return SummaryMath.percentDelta(current: total, previous: previousTotal)
    }

    /// Lowercased name of the comparison month for the "vs. maio" caption, e.g.
    /// "maio". `nil` unless there's both a delta to show and a known month.
    private var previousMonthName: String? {
        guard overallDelta != nil, let monthAnchor else { return nil }
        return monthAnchor.previousMonthAnchor.monthNamePtBR.lowercased()
    }

    /// Percent change for a category vs. last month. `nil` when there's no
    /// comparison month or the category had no prior spend (shown as "Novo").
    private func delta(for categoryID: UUID, current: Decimal) -> Double? {
        guard let previousTotals else { return nil }
        return SummaryMath.percentDelta(current: current, previous: previousTotals[categoryID] ?? 0)
    }

    private func isNew(_ categoryID: UUID) -> Bool {
        guard let previousTotals else { return false }
        return (previousTotals[categoryID] ?? 0) == 0
    }

    var body: some View {
        NavigationStack {
            List {
                if !slices.isEmpty {
                    Section {
                        ExpensesDonutHeader(
                            slices: slices,
                            total: total,
                            delta: overallDelta,
                            previousMonthName: previousMonthName
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                    }
                }

                ForEach(groups) { group in
                    Section {
                        ForEach(group.lines) { line in
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: line.source))
                                    .font(.caption)
                                    .foregroundStyle(Theme.tint(for: group.category.id))
                                    .frame(width: 18)
                                Text(line.label.isEmpty ? "—" : line.label)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(line.amount.brl)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: CategoryIcon.symbol(for: group.category.name))
                                .foregroundStyle(Theme.tint(for: group.category.id))
                            CategoryNameText(group.category.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if let delta = delta(for: group.category.id, current: group.amount) {
                                DeltaPill(value: delta, higherIsBetter: false)
                            } else if isNew(group.category.id) {
                                newTag
                            }
                            Text(group.amount.brl)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .textCase(nil)
                    }
                }
            }
            .navigationTitle("Despesas do mês")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    /// Shown when a category had no spend last month, where a percentage would
    /// be undefined (division by zero).
    private var newTag: some View {
        Text("Novo")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.red.opacity(0.15)))
    }

    private func icon(for source: SummaryMath.ExpenseLine.Source) -> String {
        switch source {
        case .recurring: return "arrow.triangle.2.circlepath"
        case .oneOff:    return "cart"
        case .invoice:   return "creditcard"
        }
    }
}

/// Large donut for the detail sheet header: plots every category and shows the
/// month total — with its month-over-month change — in the center. Tapping a
/// slice pops it out and swaps the center for that category's name, value and
/// share; tapping it again (or the center) returns to the total. Mirrors the
/// dashboard donut's interaction so both feel the same.
private struct ExpensesDonutHeader: View {
    @Environment(\.locale) private var locale
    let slices: [SpendingSlice]
    let total: Decimal
    /// Overall spend change vs. last month; `nil` hides the badge.
    var delta: Double?
    /// Comparison month name for the "vs. maio" caption; `nil` drops the suffix.
    var previousMonthName: String?

    /// Scales and fades the ring in on appear so opening the sheet feels alive.
    @State private var appeared = false
    /// Currently focused slice; `nil` shows the month total in the center.
    @State private var selectedID: UUID?

    private var selectedSlice: SpendingSlice? {
        selectedID.flatMap { id in slices.first { $0.id == id } }
    }

    private var selectionSpring: Animation { .spring(response: 0.35, dampingFraction: 0.75) }

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Valor", slice.value),
                innerRadius: .ratio(0.68),
                outerRadius: .ratio(slice.id == selectedID ? 1.0 : 0.92),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(slice.color)
            .opacity(selectedID == nil || slice.id == selectedID ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        // Manual hit-testing (as in `SpendingDonutView`) — the built-in
        // selection gesture doesn't fire reliably for taps in this layout.
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in handleTap(at: location, proxy: proxy, geo: geo) }
            }
        }
        .frame(height: 240)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .overlay { center }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total do mês \(total.brl)")
    }

    private var center: some View {
        VStack(spacing: 6) {
            Text(selectedSlice.map { CategoryLocalization.display($0.name, locale: locale) } ?? String(localized: "Total do mês"))
                .font(.caption)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text((selectedSlice?.amount ?? total).brl)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                // Keep the value inside the ring's hole (inner ratio 0.68).
                .frame(maxWidth: 150)
            if let selectedSlice {
                Text(share(selectedSlice.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else if let delta {
                deltaBadge(delta)
            }
        }
        .frame(width: 156)
        .contentShape(Circle())
        .onTapGesture {
            guard selectedID != nil else { return }
            withAnimation(selectionSpring) { selectedID = nil }
        }
        .opacity(appeared ? 1 : 0)
    }

    /// Mirrors `DeltaPill`'s styling but folds in the "vs. maio" caption the
    /// mock calls for. Rising spend is unfavorable, so up reads red.
    @ViewBuilder
    private func deltaBadge(_ value: Double) -> some View {
        let up = value >= 0
        let tint: Color = up ? .red : .green
        HStack(spacing: 3) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(Money.formatPercent(abs(value)))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            if let previousMonthName {
                Text("vs. \(previousMonthName)")
                    .font(.caption)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.15)))
    }

    private func share(_ amount: Decimal) -> String {
        guard total > 0 else { return "" }
        let ratio = NSDecimalNumber(decimal: amount / total).doubleValue
        return Money.formatPercent(ratio, fractionDigits: 0)
    }

    /// Resolves a tap on the chart to a slice: converts the point to a
    /// clockwise-from-12-o'clock angle and walks the cumulative values. A tap
    /// inside the hole clears the focus; taps outside the ring are ignored.
    private func handleTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geo[plotFrame]
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let radius = (dx * dx + dy * dy).squareRoot()
        let outer = min(frame.width, frame.height) / 2
        guard radius <= outer else { return }
        guard radius >= outer * 0.6 else {
            withAnimation(selectionSpring) { selectedID = nil }
            return
        }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let totalValue = slices.reduce(0.0) { $0 + $1.value }
        guard totalValue > 0, let tapped = slice(atAngleValue: angle / (2 * .pi) * totalValue) else { return }
        withAnimation(selectionSpring) {
            selectedID = selectedID == tapped.id ? nil : tapped.id
        }
    }

    /// Maps a tap's angle-domain value (cumulative plotted value) to its slice.
    private func slice(atAngleValue value: Double) -> SpendingSlice? {
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.value
            if value <= cumulative { return slice }
        }
        return slices.last
    }
}
