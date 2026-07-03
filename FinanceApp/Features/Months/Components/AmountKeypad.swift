import SwiftUI

/// A currency amount being typed on the custom keypad. Stores raw input with a
/// canonical "." separator regardless of locale, and formats it for display in
/// the app's presentation currency (`R$` in Portuguese, `$` in English).
///
/// Free-entry (not ATM-style): typing digits builds the integer part, the
/// separator key starts the fraction, capped at two decimal places.
struct AmountEntry: Equatable {
    private(set) var raw: String

    init() { raw = "" }

    /// Preloads an existing value for edit flows, rounded to two places.
    init(_ value: Decimal?) {
        guard let value, value > 0 else { raw = ""; return }
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        raw = NSDecimalNumber(decimal: rounded).stringValue
    }

    var decimal: Decimal { Decimal(string: raw.isEmpty ? "0" : raw) ?? 0 }
    var isEmpty: Bool { decimal == 0 }

    private var hasSeparator: Bool { raw.contains(".") }
    private var fractionCount: Int {
        guard let dot = raw.firstIndex(of: ".") else { return 0 }
        return raw.distance(from: raw.index(after: dot), to: raw.endIndex)
    }

    mutating func append(_ digit: Int) {
        guard fractionCount < 2 else { return }
        if raw == "0" { raw = "" }                 // avoid "05"
        guard raw.count < 12 else { return }        // sane upper bound
        raw += String(digit)
    }

    mutating func appendSeparator() {
        guard !hasSeparator else { return }
        raw = raw.isEmpty ? "0." : raw + "."
    }

    mutating func deleteLast() {
        guard !raw.isEmpty else { return }
        raw.removeLast()
    }

    /// Formatted for the big display, e.g. "R$ 1.250,00" / "$ 1,250.00".
    var display: String {
        let symbol = Money.presentationLocale.currencySymbol ?? ""
        let group = Money.presentationLocale.groupingSeparator ?? ","
        let dec = Money.presentationLocale.decimalSeparator ?? "."

        func withSymbol(_ body: String) -> String {
            symbol.isEmpty ? body : "\(symbol)\u{00A0}\(body)"
        }

        if raw.isEmpty { return withSymbol("0" + dec + "00") }

        let comps = raw.components(separatedBy: ".")
        let intPart = comps[0].isEmpty ? "0" : comps[0]
        var body = Self.group(intPart, separator: group)
        if hasSeparator {
            body += dec + (comps.count > 1 ? comps[1] : "")
        }
        return withSymbol(body)
    }

    /// Localized decimal separator shown on the keypad key.
    static var separatorSymbol: String { Money.presentationLocale.decimalSeparator ?? "." }

    private static func group(_ digits: String, separator: String) -> String {
        guard digits.count > 3 else { return digits }
        var result = ""
        for (offset, char) in digits.reversed().enumerated() {
            if offset != 0 && offset % 3 == 0 { result = separator + result }
            result = String(char) + result
        }
        return result
    }
}

/// Custom on-screen decimal keypad that drives an `AmountEntry`. Replaces the
/// tiny Form currency field in the add flows so the amount can be the hero.
struct AmountKeypad: View {
    @Binding var entry: AmountEntry
    var tint: Color = .accentColor

    private enum Key: Hashable { case digit(Int), separator, delete }

    private let rows: [[Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.separator, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: entry.raw)
    }

    private func keyButton(_ key: Key) -> some View {
        Button {
            press(key)
        } label: {
            label(for: key)
                .font(.title2.weight(.regular))
                .foregroundStyle(key == .delete ? tint : .primary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    @ViewBuilder
    private func label(for key: Key) -> some View {
        switch key {
        case .digit(let d): Text(verbatim: "\(d)").monospacedDigit()
        case .separator: Text(verbatim: AmountEntry.separatorSymbol)
        case .delete: Image(systemName: "delete.left")
        }
    }

    private func accessibilityLabel(for key: Key) -> LocalizedStringKey {
        switch key {
        case .digit(let d): return "\(d)"
        case .separator: return "Separador decimal"
        case .delete: return "Apagar"
        }
    }

    private func press(_ key: Key) {
        switch key {
        case .digit(let d): entry.append(d)
        case .separator: entry.appendSeparator()
        case .delete: entry.deleteLast()
        }
    }
}
