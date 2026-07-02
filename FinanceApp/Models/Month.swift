import Foundation
import SwiftData

@Model
final class Month {
    var id: UUID = UUID()
    var anchorDate: Date = Date()
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \IncomeEntry.month)
    var incomeEntries: [IncomeEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringExpenseEntry.month)
    var recurringEntries: [RecurringExpenseEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \OneOffExpense.month)
    var oneOffs: [OneOffExpense]? = []

    @Relationship(deleteRule: .cascade, inverse: \CreditCardInvoice.month)
    var invoice: CreditCardInvoice? = nil

    @Relationship(inverse: \ExpenseTemplate.skippedFromMonths)
    var skippedTemplates: [ExpenseTemplate]? = []

    init(id: UUID = UUID(), anchorDate: Date = Date(), createdAt: Date = Date()) {
        self.id = id
        self.anchorDate = anchorDate
        self.createdAt = createdAt
    }
}
