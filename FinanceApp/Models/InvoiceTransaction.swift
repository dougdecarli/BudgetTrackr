import Foundation
import SwiftData

/// One purchase (or fee) line parsed from an imported credit-card invoice PDF.
///
/// Individual transactions are the granular counterpart to `InvoiceCategoryTotal`
/// (which only stored per-category sums). Each row can be categorized on its own,
/// and its category folds into the month's overall spending breakdown via
/// `SummaryMath`. Installments carry only the current month's slice — the amount
/// the statement actually charges this cycle.
@Model
final class InvoiceTransaction {
    var id: UUID = UUID()
    var invoice: CreditCardInvoice? = nil

    /// Transaction date as printed on the statement, resolved to a full year.
    var postedDate: Date = Date()

    /// Merchant text as shown on the statement, minus the "- Parcela x/y" suffix.
    var rawDescription: String = ""

    /// Normalized merchant identity used to match/learn `MerchantRule`s. Stable
    /// across statements for the same merchant.
    var merchantKey: String = ""

    var amount: Decimal = Decimal(0)
    var category: Category? = nil

    /// Installment position, e.g. 2 of 3. `installmentTotal <= 1` means it is a
    /// single, non-installment charge.
    var installmentCurrent: Int = 0
    var installmentTotal: Int = 0

    /// True for non-purchase lines: IOF tax (and its reversal) and Nubank credit
    /// adjustments ("Ajuste a crédito"). These reconcile the total to the
    /// statement but need no category and are hidden from the review list.
    var isFee: Bool = false

    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        invoice: CreditCardInvoice? = nil,
        postedDate: Date = Date(),
        rawDescription: String = "",
        merchantKey: String = "",
        amount: Decimal = 0,
        category: Category? = nil,
        installmentCurrent: Int = 0,
        installmentTotal: Int = 0,
        isFee: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.invoice = invoice
        self.postedDate = postedDate
        self.rawDescription = rawDescription
        self.merchantKey = merchantKey
        self.amount = amount
        self.category = category
        self.installmentCurrent = installmentCurrent
        self.installmentTotal = installmentTotal
        self.isFee = isFee
        self.createdAt = createdAt
    }

    /// A charge spread over more than one month.
    var isInstallment: Bool { installmentTotal > 1 }
}
