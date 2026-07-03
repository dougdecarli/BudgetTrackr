import Foundation

/// One purchase (or fee) parsed from an invoice PDF, bank-agnostic.
struct ParsedTransaction: Equatable {
    var date: Date
    var rawDescription: String
    var merchantKey: String
    var amount: Decimal
    var installmentCurrent: Int
    var installmentTotal: Int
    var isFee: Bool
    /// A category name the statement itself provides (Itaú labels each line with
    /// a segment; Nubank does not). Already mapped to a canonical app category
    /// name, or nil. Used as a fallback categorization hint.
    var suggestedCategoryName: String?
}

/// The parsed result of one invoice PDF.
struct ParsedInvoice: Equatable {
    var transactions: [ParsedTransaction]
    /// The invoice total, reconciled to the statement's stated total.
    var total: Decimal
}

/// Which card issuer a PDF came from.
enum InvoiceBank: String {
    case nubank
    case itau
    case santander

    var displayName: String {
        switch self {
        case .nubank: return "Nubank"
        case .itau: return "Itaú"
        case .santander: return "Santander"
        }
    }
}

/// Detects the issuer of an invoice PDF and routes to the matching parser.
enum InvoiceParsing {
    /// Identifies the issuer from the extracted text, or nil if unrecognized.
    static func detectBank(in text: String) -> InvoiceBank? {
        if text.localizedCaseInsensitiveContains("Santander") {
            return .santander
        }
        if text.localizedCaseInsensitiveContains("Itaú")
            || text.localizedCaseInsensitiveContains("Itau Unibanco")
            || text.contains("Lançamentos: compras e saques") {
            return .itau
        }
        if text.localizedCaseInsensitiveContains("Nu Pagamentos")
            || text.localizedCaseInsensitiveContains("Nubank")
            || text.contains("TRANSAÇÕES") {
            return .nubank
        }
        return nil
    }

    /// Parses the PDF text, detecting the issuer. Returns nil if the issuer is
    /// unrecognized.
    static func parse(text: String, periodEnd: Date) -> (bank: InvoiceBank, invoice: ParsedInvoice)? {
        guard let bank = detectBank(in: text) else { return nil }
        switch bank {
        case .nubank:    return (bank, NubankInvoiceParser.parse(text: text, periodEnd: periodEnd))
        case .itau:      return (bank, ItauInvoiceParser.parse(text: text, periodEnd: periodEnd))
        case .santander: return (bank, SantanderInvoiceParser.parse(text: text, periodEnd: periodEnd))
        }
    }
}
