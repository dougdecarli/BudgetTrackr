import Foundation
import SwiftData

@Model
final class MerchantRule {
    var id: UUID = UUID()
    var merchantKey: String = ""
    var category: Category? = nil
    var createdAt: Date = Date()
    var lastUsedAt: Date? = nil

    init(
        id: UUID = UUID(),
        merchantKey: String = "",
        category: Category? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.merchantKey = merchantKey
        self.category = category
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
