import Foundation
import SwiftData

@Model
final class RecurringExpenseEntry {
    var id: UUID = UUID()
    var month: Month? = nil
    var template: ExpenseTemplate? = nil
    var amount: Decimal = Decimal(0)

    init(
        id: UUID = UUID(),
        month: Month? = nil,
        template: ExpenseTemplate? = nil,
        amount: Decimal = 0
    ) {
        self.id = id
        self.month = month
        self.template = template
        self.amount = amount
    }
}
