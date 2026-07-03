import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \ExpenseTemplate.category)
    var templates: [ExpenseTemplate]? = []

    @Relationship(deleteRule: .nullify, inverse: \OneOffExpense.category)
    var oneOffs: [OneOffExpense]? = []

    @Relationship(deleteRule: .nullify, inverse: \InvoiceCategoryTotal.category)
    var invoiceTotals: [InvoiceCategoryTotal]? = []

    @Relationship(deleteRule: .nullify, inverse: \InvoiceTransaction.category)
    var invoiceTransactions: [InvoiceTransaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \MerchantRule.category)
    var merchantRules: [MerchantRule]? = []

    init(id: UUID = UUID(), name: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    var referenceCount: Int {
        let templateCount = templates?.count ?? 0
        let oneOffCount = oneOffs?.count ?? 0
        let invoiceTotalCount = invoiceTotals?.count ?? 0
        let invoiceTransactionCount = invoiceTransactions?.count ?? 0
        let merchantRuleCount = merchantRules?.count ?? 0
        return templateCount + oneOffCount + invoiceTotalCount + invoiceTransactionCount + merchantRuleCount
    }
}
