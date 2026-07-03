import SwiftUI
import SwiftData

/// Shows where the month's money went as a donut chart with a legend, using the
/// shared `SpendingDonutView`. Renders nothing when there's no spending.
struct CategoryBreakdownCard: View {
    let month: Month

    private var slices: [SpendingSlice] {
        SpendingDonut.slices(from: SummaryMath.categoryBreakdown(for: month))
    }

    var body: some View {
        if !slices.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Para onde foi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                SpendingDonutView(slices: slices)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
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


