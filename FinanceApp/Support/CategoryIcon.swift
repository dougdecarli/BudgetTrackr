import Foundation

/// Maps the default category names to an SF Symbol, so breakdowns can show a
/// recognizable icon. Custom categories fall back to a generic tag. Matched on
/// the canonical (pt-BR) name, case- and accent-insensitively.
enum CategoryIcon {
    private static let symbols: [String: String] = [
        "moradia": "house.fill",
        "alimentacao": "fork.knife",
        "transporte": "car.fill",
        "saude": "cross.case.fill",
        "educacao": "book.fill",
        "lazer": "film.fill",
        "mercado": "cart.fill",
        "contas": "doc.text.fill",
        "vestuario": "tshirt.fill",
        "compras": "bag.fill",
    ]

    static func symbol(for name: String) -> String {
        let key = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return symbols[key] ?? "tag.fill"
    }
}
