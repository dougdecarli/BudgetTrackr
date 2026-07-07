import PDFKit
import Foundation

/// Row/cell-based extractor for Itaú statements whose text layer defeats both
/// `PDFDocument.string` and the generic column-split reconstruction.
///
/// The "eStatements" Itaú generator lays the charges out as a real table — date,
/// establishment and amount in *separate* columns — and its font makes PDFKit
/// inject spurious spaces inside words and numbers ("Tota l desta fatura",
/// "355, 86", "05 /08"). A single vertical column split can't keep a charge with
/// its amount (they sit in different bands), and the injected spaces break every
/// date/amount/marker the linear parser looks for.
///
/// This extractor instead reads `selectionsByLine()` fragments with their
/// on-page positions, repairs the spurious spaces inside numbers, then rebuilds
/// each charge by pairing a `DD/MM` date cell with the amount cell on the *same
/// row*. The future-installments block ("Compras parceladas") and the payment
/// lines are excluded by position/sign. It is self-validating: the rebuilt
/// charges must reconcile to the statement's stated total, otherwise it returns
/// nil so a mis-read is never imported. Used only as a last-resort fallback.
enum ItauGeometryTable {
    private struct Frag { var minX: Double; var maxX: Double; var y: Double; var text: String }

    static func parse(document: PDFDocument, periodEnd: Date) -> ParsedInvoice? {
        let frags = fragments(in: document)
        guard !frags.isEmpty else { return nil }

        let amounts = frags.filter { isAmount($0.text) }
        // The future-installments block, if present, is excluded by position:
        // anything in its column and below its header is a *next-month* charge.
        let future = frags.first { despaced($0.text).contains("comprasparceladas") }
        let futureX = future?.minX ?? .greatestFiniteMagnitude
        let futureY = future?.y ?? .greatestFiniteMagnitude

        var rows: [(y: Double, line: String)] = []
        for date in frags where isDatePrefix(date.text) {
            // Skip the payments block ("07/04 Pagamento via conta -2.973,52").
            if date.text.localizedCaseInsensitiveContains("pagamento") { continue }
            // Skip the future-installments column.
            if date.minX >= futureX - 8, date.y > futureY { continue }
            // Amount = the nearest amount cell to the right on the same row.
            let onRow = amounts.filter { abs($0.y - date.y) < 6 && $0.minX > date.maxX - 2 }
            guard let amount = onRow.min(by: { $0.minX < $1.minX }),
                  let value = parseAmount(amount.text), value > 0 else { continue }
            // Merchant = fragments strictly between the date and the amount on the
            // same row (tight tolerance avoids pulling in neighbouring rows).
            let merchant = frags
                .filter { abs($0.y - date.y) < 5 && $0.minX >= date.minX - 2 && $0.maxX <= amount.minX + 1 && $0.maxX > date.minX }
                .sorted { $0.minX < $1.minX }
                .map(\.text)
                .joined(separator: " ")
            rows.append((date.y, "\(merchant) \(amount.text)"))
        }
        guard !rows.isEmpty else { return nil }
        rows.sort { $0.y < $1.y }

        // Feed clean, one-charge-per-line text to the existing Itaú parser so it
        // reuses the installment split, segment mapping and date resolution.
        var lines = ["Lançamentos: compras e saques", "DATA ESTABELECIMENTO VALOR EM R$"]
        lines += rows.map(\.line)
        let stated = statedTotal(in: frags, amounts: amounts)
        if let stated { lines.append("Total dos lançamentos atuais \(rawAmount(stated))") }

        let parsed = ItauInvoiceParser.parse(text: lines.joined(separator: "\n"), periodEnd: periodEnd)
        guard !parsed.transactions.isEmpty else { return nil }

        // Self-validation: only trust the reconstruction if it reconciles to the
        // statement's stated total (guards against a mis-read table).
        let sum = parsed.transactions.reduce(Decimal(0)) { $0 + $1.amount }
        if let stated, abs(sum - stated) > Decimal(string: "0.02")! { return nil }
        return parsed
    }

    /// Reads just the statement's headline total, even when the line items can't
    /// be itemized. Lets the importer bring in a total-only invoice so the
    /// month's card spending stays correct while the user adds charges by hand.
    static func statedTotal(document: PDFDocument) -> Decimal? {
        let frags = fragments(in: document)
        let amounts = frags.filter { isAmount($0.text) }
        // Prefer the invoice's headline total; fall back to the charges subtotal.
        for key in ["totaldestafatura", "totaldoslancamentosatuais"] {
            guard let marker = frags.first(where: { despaced($0.text).contains(key) }) else { continue }
            if let inline = amountsIn(marker.text).last, inline > 0 { return inline }
            if let a = amounts.first(where: { abs($0.y - marker.y) < 8 && $0.minX > marker.minX }),
               let value = parseAmount(a.text), value > 0 { return value }
        }
        return nil
    }

    // MARK: - Fragments

    private static func fragments(in document: PDFDocument) -> [Frag] {
        var out: [Frag] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let full = page.selection(for: page.bounds(for: .mediaBox)) else { continue }
            for sel in full.selectionsByLine() {
                let raw = (sel.string ?? "").trimmingCharacters(in: .whitespaces)
                guard !raw.isEmpty else { continue }
                let r = sel.bounds(for: page)
                // Global y keeps pages ordered top-to-bottom while never letting a
                // row on one page pair with a row on another.
                out.append(Frag(minX: Double(r.minX), maxX: Double(r.maxX),
                                y: Double(index) * 100_000 - Double(r.minY),
                                text: despaceNumbers(raw)))
            }
        }
        return out
    }

    // MARK: - Totals

    private static func statedTotal(in frags: [Frag], amounts: [Frag]) -> Decimal? {
        guard let marker = frags.first(where: { despaced($0.text).contains("totaldoslancamentosatuais") })
                ?? frags.first(where: { despaced($0.text).contains("totaldestafatura") }) else { return nil }
        // The total may be inline on the marker, or an amount cell on its row.
        if let inline = amountsIn(marker.text).last { return inline }
        return amounts.first { abs($0.y - marker.y) < 8 && $0.minX > marker.minX }.flatMap { parseAmount($0.text) }
    }

    // MARK: - Text primitives

    /// Removes spaces that PDFKit injects inside numbers/dates ("355, 86" →
    /// "355,86", "05 /08" → "05/08"), while leaving spaces between words intact.
    private static func despaceNumbers(_ s: String) -> String {
        var t = s
        for pattern in [#"(?<=\d) (?=\d)"#, #"(?<=\d) (?=[.,/])"#, #"(?<=[.,/]) (?=\d)"#] {
            t = t.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return t
    }

    private static func despaced(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "").lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }

    private static func isDatePrefix(_ s: String) -> Bool {
        s.range(of: #"^\d{2}/\d{2}(\s|$)"#, options: .regularExpression) != nil
            && s.range(of: #"^\d{2}/\d{2}/"#, options: .regularExpression) == nil
    }

    private static func isAmount(_ s: String) -> Bool {
        s.range(of: #"^-?R?\$?\s?\d{1,3}(\.\d{3})*,\d{2}$"#, options: .regularExpression) != nil
    }

    private static func amountsIn(_ line: String) -> [Decimal] {
        let range = NSRange(line.startIndex..., in: line)
        let regex = try! NSRegularExpression(pattern: #"-?\d{1,3}(?:\.\d{3})*,\d{2}"#)
        return regex.matches(in: line, range: range).compactMap {
            Range($0.range, in: line).flatMap { parseAmount(String(line[$0])) }
        }
    }

    private static func parseAmount(_ token: String) -> Decimal? {
        let cleaned = token.replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard cleaned.range(of: #"^-?\d{1,3}(\.\d{3})*,\d{2}$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
    }

    /// Renders a Decimal back in Itaú's "1.960,77" form for the parser's total line.
    private static func rawAmount(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
