import Foundation
import SwiftData

@Model
final class OneOffExpense {
    var id: UUID = UUID()
    var month: Month? = nil
    var label: String = ""
    var category: Category? = nil
    var amount: Decimal = Decimal(0)
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        month: Month? = nil,
        label: String = "",
        category: Category? = nil,
        amount: Decimal = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.month = month
        self.label = label
        self.category = category
        self.amount = amount
        self.createdAt = createdAt
    }
}
