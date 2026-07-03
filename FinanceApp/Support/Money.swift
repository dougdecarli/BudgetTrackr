import Foundation

enum Money {
    /// Whether amounts are presented in US dollars (English) rather than
    /// Brazilian reais. Kept in sync with the app's language by `RootView`.
    /// This changes only the currency symbol and digit grouping — the stored
    /// value is untouched, there is no FX conversion.
    static var usesEnglish = false

    /// Locale for month/date formatting — always Brazilian. Currency and
    /// percentages use `presentationLocale`, which follows the language.
    static let locale = Locale(identifier: "pt_BR")

    /// Presentation locale for money and percentages: `en_US` ($) in English,
    /// `pt_BR` (R$) otherwise.
    static var presentationLocale: Locale {
        usesEnglish ? Locale(identifier: "en_US") : Locale(identifier: "pt_BR")
    }

    static var currencyCode: String { usesEnglish ? "USD" : "BRL" }

    /// FormatStyle for currency entry fields (`TextField(value:format:)`).
    static var currencyStyle: Decimal.FormatStyle.Currency {
        .currency(code: currencyCode).locale(presentationLocale)
    }

    static func format(_ value: Decimal) -> String {
        value.formatted(currencyStyle)
    }

    static func formatSigned(_ value: Decimal) -> String {
        let formatted = format(abs(value))
        return value < 0 ? "-\(formatted)" : formatted
    }

    /// Compact currency for tight spots (e.g. chart legends): thousands collapse
    /// to "k" with up to two decimals, trailing zeros dropped — `R$ 1,55k`,
    /// `R$ 4,5k`, `R$ 2k`. Values under 1.000 are shown in full.
    static func compact(_ value: Decimal) -> String {
        let symbol = presentationLocale.currencySymbol ?? ""
        let prefix = symbol.isEmpty ? "" : "\(symbol)\u{00A0}"
        let double = NSDecimalNumber(decimal: value).doubleValue

        guard abs(double) >= 1000 else {
            return prefix + String(format: "%.0f", double)
        }
        var number = String(format: "%.2f", double / 1000)
        if number.contains(".") {
            while number.hasSuffix("0") { number.removeLast() }
            if number.hasSuffix(".") { number.removeLast() }
        }
        let separator = presentationLocale.decimalSeparator ?? "."
        number = number.replacingOccurrences(of: ".", with: separator)
        return "\(prefix)\(number)k"
    }

    static func formatPercent(_ value: Double, fractionDigits: Int = 1) -> String {
        value.formatted(.percent.precision(.fractionLength(fractionDigits)).locale(presentationLocale))
    }

    static func parse(_ string: String) -> Decimal? {
        let cleaned = string
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }
}

extension Decimal {
    /// Formatted in the app's current presentation currency — `R$` in
    /// Portuguese, `$` in English. (Name kept short for call sites.)
    var brl: String { Money.format(self) }
}
