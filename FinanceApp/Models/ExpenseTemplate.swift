import Foundation
import SwiftData

@Model
final class ExpenseTemplate {
    var id: UUID = UUID()
    var label: String = ""
    var category: Category? = nil
    var isTicketCard: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \RecurringExpenseEntry.template)
    var entries: [RecurringExpenseEntry]? = []

    var skippedFromMonths: [Month]? = []

    init(
        id: UUID = UUID(),
        label: String = "",
        category: Category? = nil,
        isTicketCard: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.isTicketCard = isTicketCard
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
