import SwiftUI
import SwiftData

/// Shows where the month's money went as a donut chart with a legend, using the
/// shared `SpendingDonutView`. Renders nothing when there's no spending.
struct CategoryBreakdownCard: View {
    @Environment(\.modelContext) private var context
    let month: Month

    @State private var showingDetail = false

    private var slices: [SpendingSlice] {
        SpendingDonut.slices(from: SummaryMath.categoryBreakdown(for: month))
    }

    /// Previous month's spend per category, keyed by category id — powers the
    /// month-over-month variation shown per category in the detail sheet. `nil`
    /// when there's no earlier month to compare against.
    private var previousTotals: [UUID: Decimal]? {
        guard let prev = MonthRollover.previous(of: month, in: context) else { return nil }
        return SummaryMath.categoryBreakdown(for: prev)
            .reduce(into: [:]) { $0[$1.category.id] = $1.amount }
    }

    var body: some View {
        if !slices.isEmpty {
            // The donut handles its own taps (slice focus), so only the header
            // row opens the detail sheet — not the whole card.
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    showingDetail = true
                } label: {
                    HStack {
                        Text("Para onde foi")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SpendingDonutView(slices: slices)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .sheet(isPresented: $showingDetail) {
                MonthExpensesDetailSheet(
                    groups: SummaryMath.categorizedExpenseGroups(for: month),
                    previousTotals: previousTotals
                )
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Month.self, Category.self, OneOffExpense.self, RecurringExpenseEntry.self,
        ExpenseTemplate.self, IncomeEntry.self, IncomeSource.self,
        CreditCardInvoice.self, InvoiceCategoryTotal.self, MerchantRule.self, AppSettings.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let month = Month(anchorDate: .now)
    container.mainContext.insert(month)

    let sample: [(String, Decimal)] = [
        ("Moradia", 6180), ("Crédito", 4500), ("Mercado", 2000),
        ("Contas", 1550), ("Transporte", 900), ("Lazer", 700),
    ]
    for (name, amount) in sample {
        let category = Category(name: name)
        container.mainContext.insert(category)
        container.mainContext.insert(
            OneOffExpense(month: month, label: name, category: category, amount: amount)
        )
    }

    return ScrollView {
        CategoryBreakdownCard(month: month)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}


