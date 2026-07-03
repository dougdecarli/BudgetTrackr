import Foundation

/// Parses the text extracted from an Itaú credit-card invoice PDF.
///
/// Itaú's layout differs from Nubank's in several ways:
///
/// - Each domestic charge spans two lines (though PDFKit sometimes flips their
///   order at page breaks), e.g.
///
///       30/05 BredCapas 10/10 25,62      ← date, merchant, installment, amount
///       outros CANOAS                    ← Itaú's own segment label + city
///
/// - The statement labels every line with a segment ("supermercado",
///   "restaurante", "viagem"…), which we map to a category as a hint.
/// - International charges live in a separate "Lançamentos internacionais"
///   section where the R$ amount sits on the date line and a converted-currency
///   line follows; an IOF repasse is added so the total reconciles.
/// - A "Compras parceladas - próximas faturas" section lists *future*
///   installments, which must be excluded.
///
/// The parser is date-anchored: each domestic transaction is the run of lines
/// from one "DD/MM" up to the next, and the amount is the last monetary token in
/// that run. Both are validated to reconcile to the statement's stated total.
enum ItauInvoiceParser {
    /// Itaú segment label (normalized, diacritic-free) → canonical app category
    /// name. Labels with no sensible mapping ("outros", "serviços") are omitted
    /// so they fall through to the merchant-keyword categorizer.
    private static let segmentToCategory: [String: String] = [
        "supermercado": "Mercado", "supermarket": "Mercado",
        "restaurante": "Alimentação",
        "transporte": "Transporte",
        "saude": "Saúde",
        "educacao": "Educação",
        "viagem": "Lazer",
        "vestuario": "Vestuário", "retail": "Compras",
        "eletronicos": "Compras", "eletronics": "Compras",
    ]

    private static let segments: Set<String> = [
        "outros", "supermercado", "supermarket", "restaurante", "transporte",
        "saude", "servicos", "viagem", "vestuario", "educacao", "eletronicos",
        "eletronics", "retail",
    ]

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
        var domesticChunk: [String] = []
        var intlPurchases = Decimal(0)
        var inIntl = false
        var stopped = false

        func date(day: Int, month: Int) -> Date {
            let year = month > endMonth ? endYear - 1 : endYear
            return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? periodEnd
        }

        func flushDomestic() {
            defer { domesticChunk = [] }
            guard let first = domesticChunk.first,
                  let (day, month, _) = parseDatePrefix(first),
                  // Skip the "Pagamento via conta" line in the payments block.
                  !first.localizedCaseInsensitiveContains("pagamento") else { return }
            let joined = domesticChunk.joined(separator: " ")
            guard let amount = amounts(in: joined).last else { return }
            let (merchant, installment, segment) = splitDomestic(afterDate: joined, dateToken: dateToken(first))
            transactions.append(makeTransaction(
                merchant: merchant, amount: amount, date: date(day: day, month: month),
                installment: installment, segment: segment
            ))
        }

        var mode = Mode.none
        for line in lines {
            if line.contains("Compras parceladas - próximas faturas") { stopped = true }
            if stopped { continue }

            if line.contains("Lançamentos: compras e saques") {
                flushDomestic(); mode = .domestic; continue
            }
            if line.contains("Lançamentos internacionais") {
                flushDomestic(); mode = .international; inIntl = true; continue
            }
            if line.hasPrefix("DATA ESTABELECIMENTO") { continue }
            if line.contains("Lançamentos no cartão") || line.contains("Total dos lançamentos") {
                flushDomestic(); mode = .none; continue
            }
            // End of the international list (conversion + totals block follows).
            if mode == .international,
               line.contains("Dólar de Conversão")
                || line.contains("Total transações inter")
                || line.contains("Total lançamentos inter") {
                mode = .none; continue
            }

            switch mode {
            case .domestic:
                if isDateLine(line) { flushDomestic(); domesticChunk = [line] }
                else if !domesticChunk.isEmpty { domesticChunk.append(line) }
            case .international:
                if let (day, month, _) = parseDatePrefix(line), let amount = amounts(in: line).last {
                    let (merchant, installment, segment) = splitDomestic(afterDate: line, dateToken: dateToken(line))
                    transactions.append(makeTransaction(
                        merchant: merchant, amount: amount, date: date(day: day, month: month),
                        installment: installment, segment: segment
                    ))
                    intlPurchases += amount
                }
            case .none:
                break
            }
        }
        flushDomestic()

        // International IOF repasse: the difference between the section's grand
        // total and the sum of its purchases. Added as a fee so the invoice
        // reconciles to the stated total.
        if inIntl, let grand = internationalGrandTotal(in: lines) {
            let iof = grand - intlPurchases
            if iof > Decimal(string: "0.005")! {
                transactions.append(ParsedTransaction(
                    date: periodEnd, rawDescription: "IOF internacional", merchantKey: "iof internacional",
                    amount: iof, installmentCurrent: 0, installmentTotal: 0, isFee: true,
                    suggestedCategoryName: nil
                ))
            }
        }

        let stated = statedTotal(in: lines)
        let summed = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        return ParsedInvoice(transactions: transactions, total: stated ?? summed)
    }

    private enum Mode { case none, domestic, international }

    // MARK: - Field extraction

    private static func makeTransaction(
        merchant: String, amount: Decimal, date: Date, installment: (Int, Int), segment: String?
    ) -> ParsedTransaction {
        let suggested = segment.flatMap { segmentToCategory[$0] }
        return ParsedTransaction(
            date: date,
            rawDescription: merchant,
            merchantKey: NubankInvoiceParser.merchantKey(from: merchant),
            amount: amount,
            installmentCurrent: installment.0,
            installmentTotal: installment.1,
            isFee: false,
            suggestedCategoryName: suggested
        )
    }

    /// Splits the transaction text (a date-anchored run) into merchant, the
    /// installment pair, and the Itaú segment label. Robust to the amount landing
    /// before or after the segment (PDFKit flips them at page breaks).
    private static func splitDomestic(
        afterDate joined: String, dateToken: String
    ) -> (merchant: String, installment: (Int, Int), segment: String?) {
        let body = String(joined.dropFirst(dateToken.count)).trimmingCharacters(in: .whitespaces)
        let tokens = body.split(separator: " ").map(String.init)

        // Installment token "10/10" (not the leading date, already dropped).
        var installment = (0, 0)
        if let match = body.range(of: #"\b\d{1,2}/\d{2}\b"#, options: .regularExpression) {
            let parts = body[match].split(separator: "/").compactMap { Int($0) }
            if parts.count == 2 { installment = (parts[0], parts[1]) }
        }

        // The segment label splits merchant (before) from city (after).
        var segment: String?
        var merchantTokens: [String] = []
        for token in tokens {
            let folded = fold(token)
            if segment == nil, segments.contains(folded) {
                segment = folded
                break
            }
            merchantTokens.append(token)
        }
        // Drop installment ("04/05") and monetary tokens from the merchant name.
        merchantTokens.removeAll {
            parseAmount($0) != nil || $0.range(of: #"^\d{1,2}/\d{2}$"#, options: .regularExpression) != nil
        }
        return (merchantTokens.joined(separator: " "), installment, segment)
    }

    // MARK: - Totals

    private static func statedTotal(in lines: [String]) -> Decimal? {
        for (i, line) in lines.enumerated() where line.contains("Total desta fatura") {
            if let last = amounts(in: line).last { return last }
            if i + 1 < lines.count, let next = amounts(in: lines[i + 1]).first { return next }
        }
        return nil
    }

    /// The "Total lançamentos inter. em R$" value — the last of the three numbers
    /// in the international totals block (transações, IOF, total).
    private static func internationalGrandTotal(in lines: [String]) -> Decimal? {
        let labelIndex = lines.firstIndex { $0.contains("Total lançamentos inter") }
            ?? lines.firstIndex { $0.contains("Total transações inter") }
        guard let index = labelIndex else { return nil }
        var numbers: [Decimal] = []
        if let last = amounts(in: lines[index]).last { numbers.append(last) }
        var k = index + 1
        while k < lines.count, let value = parseAmount(lines[k]) {
            numbers.append(value); k += 1
        }
        return numbers.last
    }

    // MARK: - Primitives

    private static func isDateLine(_ line: String) -> Bool {
        line.range(of: #"^\d{2}/\d{2}\b"#, options: .regularExpression) != nil
    }

    private static func dateToken(_ line: String) -> String {
        String(line.prefix(5)) // "DD/MM"
    }

    static func parseDatePrefix(_ line: String) -> (day: Int, month: Int, rest: String)? {
        guard let match = line.range(of: #"^(\d{2})/(\d{2})\b"#, options: .regularExpression) else { return nil }
        let token = String(line[match])
        let parts = token.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 2, (1...31).contains(parts[0]), (1...12).contains(parts[1]) else { return nil }
        return (parts[0], parts[1], String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces))
    }

    /// All monetary tokens in a line, as Decimals.
    private static func amounts(in line: String) -> [Decimal] {
        let range = NSRange(line.startIndex..., in: line)
        let regex = try! NSRegularExpression(pattern: amountPattern)
        return regex.matches(in: line, range: range).compactMap {
            Range($0.range, in: line).flatMap { parseAmount(String(line[$0])) }
        }
    }

    /// Parses an Itaú amount ("1.021,57", "-8.236,91") into a Decimal.
    static func parseAmount(_ token: String) -> Decimal? {
        guard token.range(of: #"^-?\d{1,3}(?:\.\d{3})*,\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let normalized = token
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
