import Foundation
import SwiftData

@Model
final class CreditCardInvoice {
    var id: UUID = UUID()
    var month: Month? = nil
    var uploadedAt: Date = Date()
    var totalAmount: Decimal = Decimal(0)

    /// Issuer/display label for this card's statement (e.g. "Nubank", "Itaú"),
    /// used to tell one card's invoice apart from another's when a month holds
    /// more than one. Empty on invoices imported before multi-card support.
    var bankName: String = ""

    @Relationship(deleteRule: .cascade, inverse: \InvoiceCategoryTotal.invoice)
    var categoryTotals: [InvoiceCategoryTotal]? = []

    @Relationship(deleteRule: .cascade, inverse: \InvoiceTransaction.invoice)
    var transactions: [InvoiceTransaction]? = []

    init(
        id: UUID = UUID(),
        month: Month? = nil,
        uploadedAt: Date = Date(),
        totalAmount: Decimal = 0,
        bankName: String = ""
    ) {
        self.id = id
        self.month = month
        self.uploadedAt = uploadedAt
        self.totalAmount = totalAmount
        self.bankName = bankName
    }
}
