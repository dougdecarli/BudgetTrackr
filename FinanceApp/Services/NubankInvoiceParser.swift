import Foundation

/// Parses the text extracted from a Nubank credit-card invoice PDF into a list of
/// transactions.
///
/// PDFKit renders each transaction as a single line, in reading order:
///
///     02 JUN •••• 0108 Ifd*Emporio das Massas R$ 39,89
///     02 JUN Decolar C - NuPay - Parcela 10/12 R$ 1.049,01   (no card mask)
///
/// International charges are the exception — the amount lands a few lines later,
/// after the currency-conversion lines:
///
///     07 JUN •••• 0108 Anthropic* Claude Sub
///     BRL 110.00 = USD 21.57
///     Conversão: BRL 5.30 = USD 1 = R$ 5,30
///     R$ 114,40
///
/// We only read the "TRANSAÇÕES" section and stop at "Pagamentos e
/// Financiamentos" (payments of the previous invoice, not spending). Parsing is
/// pure and line-based so it can be unit-tested without PDFKit.
enum NubankInvoiceParser {
    private static let monthAbbreviations: [String: Int] = [
        "JAN": 1, "FEV": 2, "MAR": 3, "ABR": 4, "MAI": 5, "JUN": 6,
        "JUL": 7, "AGO": 8, "SET": 9, "OUT": 10, "NOV": 11, "DEZ": 12,
    ]

    /// - Parameters:
    ///   - text: the full extracted PDF text.
    ///   - periodEnd: the closing date of the invoice being imported (the month's
    ///     anchor date is a good source). Used to resolve each transaction's year
    ///     and correctly roll a December→January statement across the year.
    static func parse(text: String, periodEnd: Date) -> ParsedInvoice {
        let calendar = Calendar(identifier: .gregorian)
        let endComponents = calendar.dateComponents([.year, .month], from: periodEnd)
        let endYear = endComponents.year ?? 2000
        let endMonth = endComponents.month ?? 12

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var transactions: [ParsedTransaction] = []
        var capturing = false
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.localizedCaseInsensitiveContains("TRANSAÇÕES") {
                capturing = true
            }
            // Everything after this header is prior-invoice payments, not spend.
            if line.localizedCaseInsensitiveContains("Pagamentos e Financiamentos") {
                break
            }

            guard capturing, let (day, month, rest) = parseDatePrefix(line) else {
                index += 1
                continue
            }

            // Strip the optional "•••• 0108" card mask, leaving "<merchant> R$ x".
            let body = stripCardMask(rest)

            var amount: Decimal?
            var description = body

            if let (value, name) = splitTrailingAmount(body) {
                amount = value
                description = name
            } else {
                // International charge: the amount is a few lines down, after the
                // BRL/USD conversion lines. Scan forward for a standalone amount.
                var cursor = index + 1
                while cursor < lines.count {
                    if parseDatePrefix(lines[cursor]) != nil { break }
                    if let value = parseAmount(lines[cursor]) {
                        amount = value
                        index = cursor
                        break
                    }
                    cursor += 1
                }
            }

            let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
            guard let amount, !trimmedDescription.isEmpty else {
                index += 1
                continue
            }
            guard !isInvoicePaymentLine(trimmedDescription) else {
                index += 1
                continue
            }

            let year = month > endMonth ? endYear - 1 : endYear
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? periodEnd
            let (name, current, total) = splitInstallment(trimmedDescription)
            let isFee = isNonPurchaseLine(name)

            transactions.append(
                ParsedTransaction(
                    date: date,
                    rawDescription: name,
                    merchantKey: merchantKey(from: name),
                    amount: amount,
                    installmentCurrent: current,
                    installmentTotal: total,
                    isFee: isFee,
                    suggestedCategoryName: nil
                )
            )
            index += 1
        }

        let total = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        return ParsedInvoice(transactions: transactions, total: total)
    }

    // MARK: - Line parsing

    /// A line that reconciles the total but is not a categorizable purchase: IOF
    /// tax lines and Nubank credit adjustments ("Ajuste a crédito"). These are
    /// flagged so the review UI hides them and never asks for a category, while
    /// they still count toward the invoice total.
    private static func isNonPurchaseLine(_ name: String) -> Bool {
        let patterns = [#"^IOF\b"#, #"^Ajuste\b"#]
        return patterns.contains {
            name.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// Nubank can expose invoice payments as dated lines (for example
    /// "Pagamento em 03 MAI"). They reduce the card balance, but are not spending
    /// and must not make the imported invoice total negative.
    private static func isInvoicePaymentLine(_ name: String) -> Bool {
        name.range(of: #"^Pagamento\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Matches a "DD MMM " prefix (no year, so header lines like "FATURA 09 JUL
    /// 2026" are ignored) and returns the day, month, and the rest of the line.
    static func parseDatePrefix(_ line: String) -> (day: Int, month: Int, rest: String)? {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 2, let day = Int(parts[0]), (1...31).contains(day),
              let month = monthAbbreviations[parts[1].uppercased()] else {
            return nil
        }
        return (day, month, String(parts[2]))
    }

    /// Removes a leading "•••• 0108" card mask, if present.
    private static func stripCardMask(_ text: String) -> String {
        guard let range = text.range(
            of: #"^[•·∙\*\.]{2,}\s*\d{4}\s+"#,
            options: .regularExpression
        ) else { return text }
        return String(text[range.upperBound...])
    }

    /// Splits "<merchant> … R$ 39,89" into (39.89, "<merchant> …"). Returns nil
    /// when the line has no trailing amount (an international charge, whose amount
    /// is on a later line).
    private static func splitTrailingAmount(_ text: String) -> (amount: Decimal, name: String)? {
        guard let range = text.range(
            of: #"[−-]?\s*R\$\s*[\d.]+,\d{2}$"#,
            options: .regularExpression
        ), let amount = parseAmount(String(text[range])) else { return nil }
        let name = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return (amount, name)
    }

    /// Parses "R$ 1.234,56" / "−R$ 4,00" / "-R$ 4,00" into a Decimal. Anchored to
    /// the whole line so an international-conversion line ("Conversão: … = R$ 5,30")
    /// is never mistaken for the transaction amount.
    static func parseAmount(_ line: String) -> Decimal? {
        let cleaned = line
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard cleaned.range(
            of: #"^[−-]?\s*R\$\s*[\d.]+,\d{2}$"#,
            options: .regularExpression
        ) != nil else { return nil }
        let negative = cleaned.hasPrefix("−") || cleaned.hasPrefix("-")
        let digits = cleaned
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "−", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: digits) else { return nil }
        return negative ? -value : value
    }

    /// Splits "Casa da Bebida - Parcela 3/3" into ("Casa da Bebida", 3, 3).
    /// Returns (original, 0, 0) when there is no installment suffix.
    static func splitInstallment(_ description: String) -> (name: String, current: Int, total: Int) {
        guard let match = description.range(
            of: #"\s*[-–]\s*Parcela\s+(\d+)/(\d+)\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return (description.trimmingCharacters(in: .whitespaces), 0, 0)
        }
        let suffix = String(description[match])
        let numbers = suffix.components(separatedBy: CharacterSet(charactersIn: "/ "))
            .compactMap { Int($0) }
        let name = String(description[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard numbers.count >= 2 else { return (name, 0, 0) }
        return (name, numbers[0], numbers[1])
    }

    /// Normalizes a merchant name into a stable key for `MerchantRule` matching:
    /// diacritics stripped, lowercased, whitespace collapsed.
    static func merchantKey(from name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let collapsed = folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }
}
