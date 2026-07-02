import Foundation
import SwiftData

@Model
final class IncomeSource {
    var id: UUID = UUID()
    var label: String = ""
    var type: IncomeType = IncomeType.income
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \IncomeEntry.source)
    var entries: [IncomeEntry]? = []

    init(
        id: UUID = UUID(),
        label: String = "",
        type: IncomeType = .income,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
