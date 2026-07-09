import SwiftUI

/// Drill-down from the invoice breakdown: every purchase in a single category
/// across the month's cards, with the category total up top. Tapping a purchase
/// opens the category picker so it can be recategorized in place — the caller
/// persists the choice and learns the merchant rule (same path as the review
/// list).
struct InvoiceCategoryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category
    /// The category's purchases, already filtered and sorted by the caller.
    let transactions: [InvoiceTransaction]
    /// Applies a new category to a purchase (and learns the merchant rule).
    /// Runs on the review screen so it can update every card in the month.
    var onRecategorize: (InvoiceTransaction, Category) -> Void

    @State private var editing: InvoiceTransaction?

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
                        Button {
                            editing = txn
                        } label: {
                            InvoiceTransactionRow(transaction: txn)
                        }
                        .buttonStyle(.plain)
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
            .sheet(item: $editing) { txn in
                InvoiceCategorySheet(transaction: txn) { newCategory in
                    onRecategorize(txn, newCategory)
                }
            }
        }
    }
}
