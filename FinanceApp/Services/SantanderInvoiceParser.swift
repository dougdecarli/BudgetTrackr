import Foundation

/// Parses the text extracted from a Santander credit-card invoice PDF.
///
/// The statement lists charges under "Detalhamento da Fatura", grouped per card
/// into subsections — "Pagamento e Demais Créditos" (the previous-invoice
/// payment plus refunds), "Despesas", and "Parcelamentos". Columns are
/// `Compra Data Descrição Parcela R$ US$`, so a line looks like:
///
///     07/06 IFD*IFOOD 7,95                        (date, merchant, amount)
///     3 10/06 MAXI BELEZA 84,99                   (leading "Compra" digit, ignored)
///     27/04 AIRBNB PAGAM*AIRB 02/04 580,35        (with a "Parcela" 02/04 column)
///     10/05 SHEIN *SHEINCOM -5,62                 (a refund credit)
///
/// The previous-invoice payment ("DEB AUTOM DE FATURA") is excluded; refunds are
/// kept as fee lines so the total reconciles. The imported transactions sum to
/// the statement's "Saldo Desta Fatura" (domestic purchases − credits).
enum SantanderInvoiceParser {
    private static let amountPattern = #"-?\d{1,3}(?:\.\d{3})*,\d{2}"#

    static func parse(text: String, periodEnd: Date) -> ParsedInvoice {
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.dateComponents([.year, .month], from: periodEnd)
        let endYear = end.year ?? 2000
        let endMonth = end.month ?? 12

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var transactions: [ParsedTransaction] = []
        var mode = Mode.none
        var capturing = false

        for line in lines {
            if line.contains("Detalhamento da Fatura") { capturing = true; continue }
            if line.contains("Resumo da Fatura") { break }
            guard capturing else { continue }

            if line.contains("Pagamento e Demais Créditos") { mode = .credits; continue }
            if line == "Despesas" || line == "Parcelamentos" { mode = .purchases; continue }
            // Skip column headers, per-card totals, and cardholder lines.
            if line.hasPrefix("Compra Data") || line.hasPrefix("Cartão Parcela")
                || line.contains("VALOR TOTAL") || line.contains("XXXX") || line.hasPrefix("@") {
                continue
            }
            guard mode != .none, let parsed = parseLine(line) else { continue }
            guard parsed.amount != 0 else { continue }

            switch mode {
            case .credits:
                // Exclude the previous-invoice payment; keep refunds as fees.
                if parsed.description.range(
                    of: #"DEB AUTOM|PAGAMENTO|PGTO"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil { continue }
                transactions.append(makeTransaction(parsed, isFee: true, endYear: endYear, endMonth: endMonth, calendar: calendar, periodEnd: periodEnd))
            case .purchases:
                transactions.append(makeTransaction(parsed, isFee: false, endYear: endYear, endMonth: endMonth, calendar: calendar, periodEnd: periodEnd))
            case .none:
                break
            }
        }

        let total = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        return ParsedInvoice(transactions: transactions, total: total)
    }

    private enum Mode { case none, credits, purchases }

    private struct ParsedLine {
        var day: Int
        var month: Int
        var description: String
        var amount: Decimal
        var installmentCurrent: Int
        var installmentTotal: Int
    }

    private static func makeTransaction(
        _ line: ParsedLine, isFee: Bool, endYear: Int, endMonth: Int,
        calendar: Calendar, periodEnd: Date
    ) -> ParsedTransaction {
        let year = line.month > endMonth ? endYear - 1 : endYear
        let date = calendar.date(from: DateComponents(year: year, month: line.month, day: line.day)) ?? periodEnd
        return ParsedTransaction(
            date: date,
            rawDescription: line.description,
            merchantKey: NubankInvoiceParser.merchantKey(from: line.description),
            amount: line.amount,
            installmentCurrent: line.installmentCurrent,
            installmentTotal: line.installmentTotal,
            isFee: isFee,
            suggestedCategoryName: nil
        )
    }

    /// Extracts date, merchant, installment, and amount from a transaction line.
    /// The date is the first "DD/MM" token; a second such token is the
    /// installment ("02/04"); the amount is the last monetary token. Any leading
    /// "Compra" digit before the date is ignored.
    private static func parseLine(_ line: String) -> ParsedLine? {
        let dates = matches(in: line, pattern: #"\d{2}/\d{2}"#)
        guard let dateMatch = dates.first else { return nil }
        let dateParts = dateMatch.text.split(separator: "/").compactMap { Int($0) }
        guard dateParts.count == 2, (1...31).contains(dateParts[0]), (1...12).contains(dateParts[1]) else { return nil }

        let amountMatches = matches(in: line, pattern: amountPattern)
        guard let amountMatch = amountMatches.last, let amount = parseAmount(amountMatch.text) else { return nil }

        var installment = (current: 0, total: 0)
        var descriptionEnd = amountMatch.range.lowerBound
        if dates.count >= 2 {
            let parcela = dates[1].text.split(separator: "/").compactMap { Int($0) }
            if parcela.count == 2 { installment = (parcela[0], parcela[1]) }
            descriptionEnd = dates[1].range.lowerBound
        }

        let description = String(line[dateMatch.range.upperBound..<descriptionEnd])
            .trimmingCharacters(in: .whitespaces)
        guard !description.isEmpty else { return nil }

        return ParsedLine(
            day: dateParts[0], month: dateParts[1], description: description,
            amount: amount, installmentCurrent: installment.current, installmentTotal: installment.total
        )
    }

    private static func matches(in line: String, pattern: String) -> [(text: String, range: Range<String.Index>)] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            Range(match.range, in: line).map { (String(line[$0]), $0) }
        }
    }

    static func parseAmount(_ token: String) -> Decimal? {
        guard token.range(of: #"^-?\d{1,3}(?:\.\d{3})*,\d{2}$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: token.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
    }
}
