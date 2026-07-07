import SwiftUI

/// Drill-down from the invoice breakdown: every purchase in a single category
/// across the month's cards, with the category total up top. Read-only — edits
/// happen back on the review list.
struct InvoiceCategoryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category
    /// The category's purchases, already filtered and sorted by the caller.
    let transactions: [InvoiceTransaction]

    private var total: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }

    private var tint: Color { Theme.tint(for: category.id) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(tint.opacity(0.15))
                            Image(systemName: CategoryIcon.symbol(for: category.name))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(tint)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 2) {
                            CategoryNameText(category.name)
                                .font(.headline)
                            Text("\(transactions.count) \(transactions.count == 1 ? "lançamento" : "lançamentos")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(total.brl)
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(transactions) { txn in
                        InvoiceTransactionRow(transaction: txn)
                    }
                }
            }
            .navigationTitle("Lançamentos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
