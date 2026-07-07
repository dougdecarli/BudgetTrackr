import SwiftUI

/// Drill-down behind the month's "Para onde foi" donut: every categorized
/// expense, grouped by category. Each category is a section with its total in
/// the header and the individual lines — recurring, avulsa or fatura — beneath.
struct MonthExpensesDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let groups: [SummaryMath.ExpenseGroup]

    private var total: Decimal {
        groups.reduce(0) { $0 + $1.amount }
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

    private func icon(for source: SummaryMath.ExpenseLine.Source) -> String {
        switch source {
        case .recurring: return "arrow.triangle.2.circlepath"
        case .oneOff:    return "cart"
        case .invoice:   return "creditcard"
        }
    }
}
