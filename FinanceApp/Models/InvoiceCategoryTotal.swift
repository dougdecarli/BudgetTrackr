import Foundation
import SwiftData

@Model
final class InvoiceCategoryTotal {
    var id: UUID = UUID()
    var invoice: CreditCardInvoice? = nil
    var category: Category? = nil
    var amount: Decimal = Decimal(0)

    init(
        id: UUID = UUID(),
        invoice: CreditCardInvoice? = nil,
        category: Category? = nil,
        amount: Decimal = 0
    ) {
        self.id = id
        self.invoice = invoice
        self.category = category
        self.amount = amount
    }
}
