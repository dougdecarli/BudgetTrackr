import Foundation
import SwiftData

/// Deterministic, realistic data used only when the app is launched with
/// `-ScreenshotMode`. The store itself is in-memory (see `FinanceAppApp`), so
/// this never touches production data or CloudKit.
enum ScreenshotDemoData {
    static func seed(in context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        let showsOnboarding = arguments.contains("-ShowOnboarding")
        let isEnglish = arguments.contains("-ScreenshotEnglish")

        let settings = fetchSettings(in: context)
        settings.hasCompletedOnboarding = !showsOnboarding
        settings.language = isEnglish ? .english : .portuguese

        let categories = fetchCategories(in: context)
        guard
            let housing = categories["Moradia"],
            let food = categories["Alimentação"],
            let transport = categories["Transporte"],
            let health = categories["Saúde"],
            let leisure = categories["Lazer"],
            let groceries = categories["Mercado"],
            let bills = categories["Contas"],
            let shopping = categories["Compras"]
        else { return }

        let salary = IncomeSource(label: isEnglish ? "Salary" : "Salário", type: .income)
        let mealBenefit = IncomeSource(label: isEnglish ? "Meal benefit" : "Vale-refeição", type: .benefit)
        let rent = ExpenseTemplate(label: isEnglish ? "Rent" : "Aluguel", category: housing)
        let electricity = ExpenseTemplate(label: isEnglish ? "Utilities & internet" : "Energia e internet", category: bills)
        let gym = ExpenseTemplate(label: isEnglish ? "Gym" : "Academia", category: health)
        let lunch = ExpenseTemplate(label: isEnglish ? "Lunch" : "Almoço", category: food, isTicketCard: true)
        context.insert(salary)
        context.insert(mealBenefit)
        [rent, electricity, gym, lunch].forEach(context.insert)

        let calendar = Calendar.current
        let currentAnchor = Date().monthAnchor

        // A full rolling year gives the Trends tab enough history to look useful
        // in every month of the calendar year.
        for offset in stride(from: -12, through: 0, by: 1) {
            guard let anchor = calendar.date(byAdding: .month, value: offset, to: currentAnchor) else { continue }
            let month = Month(anchorDate: anchor)
            context.insert(month)

            let cycle = offset + 12
            let phase = Decimal(cycle)
            let salaryAmount: Decimal = 11_900 + phase * 55
            let benefitAmount: Decimal = 780 + Decimal(cycle % 3) * 35
            context.insert(IncomeEntry(month: month, source: salary, amount: salaryAmount))
            context.insert(IncomeEntry(month: month, source: mealBenefit, amount: benefitAmount))

            context.insert(RecurringExpenseEntry(month: month, template: rent, amount: 3_250))
            context.insert(RecurringExpenseEntry(month: month, template: electricity, amount: 490 + phase * 6))
            context.insert(RecurringExpenseEntry(month: month, template: gym, amount: 189))
            context.insert(RecurringExpenseEntry(month: month, template: lunch, amount: 620 + phase * 5))

            let groceriesAmount: Decimal = 920 + Decimal(cycle % 4) * 65
            let transportAmount: Decimal = 310 + Decimal(cycle % 5) * 28
            context.insert(OneOffExpense(month: month, label: isEnglish ? "Monthly groceries" : "Compras do mês", category: groceries, amount: groceriesAmount, createdAt: day(8, in: anchor)))
            context.insert(OneOffExpense(month: month, label: isEnglish ? "Transport" : "Transporte", category: transport, amount: transportAmount, createdAt: day(12, in: anchor)))

            let invoice = CreditCardInvoice(
                month: month,
                uploadedAt: day(18, in: anchor),
                totalAmount: 2_210 + phase * 42,
                bankName: "Nubank"
            )
            context.insert(invoice)

            let merchantRows: [(String, Decimal, Category, Int, Int)] = [
                (isEnglish ? "Pão de Açúcar Market" : "Supermercado Pão de Açúcar", 612 + phase * 8, groceries, 0, 0),
                ("iFood", 284 + phase * 4, food, 0, 0),
                ("Uber", 196 + phase * 3, transport, 0, 0),
                (isEnglish ? "São Paulo Pharmacy" : "Farmácia São Paulo", 168, health, 0, 0),
                (isEnglish ? "Cultura Bookstore" : "Livraria Cultura", 149, shopping, 2, 3),
                ("Netflix", 59.90, leisure, 0, 0),
            ]

            var categorizedTotal: Decimal = 0
            for (index, row) in merchantRows.enumerated() {
                categorizedTotal += row.1
                context.insert(InvoiceTransaction(
                    invoice: invoice,
                    postedDate: day(5 + index * 2, in: anchor),
                    rawDescription: row.0,
                    merchantKey: row.0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current),
                    amount: row.1,
                    category: row.2,
                    installmentCurrent: row.3,
                    installmentTotal: row.4
                ))
            }

            // Reconcile the visible invoice total while retaining a varied set
            // of clean, categorized merchant rows for the review screen.
            let remainder = invoice.totalAmount - categorizedTotal
            if remainder > 0 {
                context.insert(InvoiceTransaction(
                    invoice: invoice,
                    postedDate: day(17, in: anchor),
                    rawDescription: isEnglish ? "Home & Design" : "Casa & Design",
                    merchantKey: "casa & design",
                    amount: remainder,
                    category: housing,
                    installmentCurrent: 1,
                    installmentTotal: 4
                ))
            }
        }

        try? context.save()
    }

    private static func fetchSettings(in context: ModelContext) -> AppSettings {
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return settings
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    private static func fetchCategories(in context: ModelContext) -> [String: Category] {
        let values = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        return Dictionary(uniqueKeysWithValues: values.map { ($0.name, $0) })
    }

    private static func day(_ day: Int, in month: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: month)
        components.day = day
        return Calendar.current.date(from: components) ?? month
    }
}
