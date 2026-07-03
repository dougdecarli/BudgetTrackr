import Foundation
import SwiftData

@Model
final class CreditCardInvoice {
    var id: UUID = UUID()
    var month: Month? = nil
    var uploadedAt: Date = Date()
    var totalAmount: Decimal = Decimal(0)

    @Relationship(deleteRule: .cascade, inverse: \InvoiceCategoryTotal.invoice)
    var categoryTotals: [InvoiceCategoryTotal]? = []

    @Relationship(deleteRule: .cascade, inverse: \InvoiceTransaction.invoice)
    var transactions: [InvoiceTransaction]? = []

    init(
        id: UUID = UUID(),
        month: Month? = nil,
        uploadedAt: Date = Date(),
        totalAmount: Decimal = 0
    ) {
        self.id = id
        self.month = month
        self.uploadedAt = uploadedAt
        self.totalAmount = totalAmount
    }
}
