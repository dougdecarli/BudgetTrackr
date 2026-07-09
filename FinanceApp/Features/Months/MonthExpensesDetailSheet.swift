import SwiftUI

/// Drill-down behind the month's "Para onde foi" donut: every categorized
/// expense, grouped by category. Each category is a section with its total in
/// the header and the individual lines — recurring, avulsa or fatura — beneath.
struct MonthExpensesDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let groups: [SummaryMath.ExpenseGroup]
    /// Previous month's spend per category id, or `nil` when there's no earlier
    /// month. Drives the month-over-month variation badges.
    var previousTotals: [UUID: Decimal]? = nil

    private var total: Decimal {
        groups.reduce(0) { $0 + $1.amount }
    }

    private var previousTotal: Decimal? {
        previousTotals.map { $0.values.reduce(0, +) }
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
                Section {
                    LabeledContent("Total de despesas") {
                        Text(total.brl)
                            .font(.headline)
                            .monospacedDigit()
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
