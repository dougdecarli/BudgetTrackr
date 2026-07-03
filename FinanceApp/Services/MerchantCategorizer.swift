import Foundation

/// Suggests a category for an invoice transaction.
///
/// Nubank statements don't carry a category, so we infer one from the merchant
/// name in two tiers:
///
/// 1. **Learned rules** (`MerchantRule`) — an exact match on the normalized
///    merchant key. This is what the user confirmed on a previous statement, so
///    it wins and makes recurring merchants fully automatic.
/// 2. **Seed keywords** — a built-in map from common Brazilian merchants to the
///    app's default category names, used only as a first guess when no rule
///    exists yet.
///
/// When neither tier resolves, the transaction stays uncategorized and the user
/// picks one — which then becomes a learned rule for next time.
enum MerchantCategorizer {
    /// Keyword → canonical (pt-BR) default category name. Keywords are matched
    /// against the normalized (diacritic-free, lowercased) merchant key.
    private static let seed: [(keyword: String, category: String)] = [
        // Alimentação — delivery, restaurants, bars, cafés. Keywords are matched
        // as substrings, so "restaur" also catches "restaura"/"restaurant".
        ("ifd*", "Alimentação"), ("ifood", "Alimentação"), ("99food", "Alimentação"),
        ("rappi", "Alimentação"), ("restaur", "Alimentação"), ("lanch", "Alimentação"),
        ("lancheria", "Alimentação"), ("pizza", "Alimentação"), ("churrasc", "Alimentação"),
        ("sushi", "Alimentação"), ("bar e cozinha", "Alimentação"), ("cozinha", "Alimentação"),
        ("burger", "Alimentação"), ("mcdonald", "Alimentação"), ("zamp", "Alimentação"),
        ("emporio", "Alimentação"), ("donna", "Alimentação"), ("cafe", "Alimentação"),
        ("bistro", "Alimentação"), ("padaria", "Alimentação"), ("acai", "Alimentação"),
        ("tratoria", "Alimentação"), ("trattoria", "Alimentação"), ("meson", "Alimentação"),
        ("gran armazem", "Alimentação"), ("casa di paolo", "Alimentação"),
        ("buffon", "Alimentação"), ("kampeki", "Alimentação"),
        ("cervej", "Alimentação"), ("gastronomia", "Alimentação"),
        ("cacau show", "Alimentação"), ("doca bar", "Alimentação"),
        // Mercado — groceries & convenience
        ("zaffari", "Mercado"), ("carrefour", "Mercado"), ("mercado", "Mercado"),
        ("supermerc", "Mercado"), ("boutique de carnes", "Mercado"), ("casa da bebida", "Mercado"),
        ("comercial de alime", "Mercado"), ("hortifruti", "Mercado"), ("pao de acucar", "Mercado"),
        ("atacad", "Mercado"), ("unisuper", "Mercado"), ("oxxo", "Mercado"),
        // Transporte — rides, fuel, parking, tolls, dealerships
        ("uber", "Transporte"), ("99*", "Transporte"), ("99 *", "Transporte"),
        ("99app", "Transporte"), ("cabify", "Transporte"), ("posto", "Transporte"),
        ("shell", "Transporte"), ("ipiranga", "Transporte"), ("abastece", "Transporte"),
        ("estaciona", "Transporte"), ("estapar", "Transporte"), ("sinoscar", "Transporte"),
        ("tagitau", "Transporte"), ("sem parar", "Transporte"), ("veloe", "Transporte"),
        ("conectcar", "Transporte"), ("otb park", "Transporte"),
        // Saúde — pharmacies, health plans
        ("farmacia", "Saúde"), ("drogaria", "Saúde"), ("droga", "Saúde"),
        ("rd saude", "Saúde"), ("saude", "Saúde"), ("panvel", "Saúde"),
        ("pague menos", "Saúde"), ("clinica", "Saúde"), ("hospital", "Saúde"),
        ("unimed", "Saúde"), ("amil", "Saúde"), ("hapvida", "Saúde"), ("raia", "Saúde"),
        // Lazer — travel, streaming, entertainment, games (no dedicated defaults)
        ("decolar", "Lazer"), ("airbnb", "Lazer"), ("latam", "Lazer"),
        ("booking", "Lazer"), ("smiles", "Lazer"), ("hotel", "Lazer"),
        ("resort", "Lazer"), ("cancun", "Lazer"), ("estadios", "Lazer"),
        ("netflix", "Lazer"), ("spotify", "Lazer"), ("youtub", "Lazer"),
        ("hbo", "Lazer"), ("disney", "Lazer"), ("zig*", "Lazer"),
        ("globo*", "Lazer"), ("playstat", "Lazer"), ("playstation", "Lazer"),
        ("xbox", "Lazer"), ("nintendo", "Lazer"), ("steam games", "Lazer"),
        // Contas — subscriptions, insurance, utilities. Specific before generic:
        // "amazon prime" must win over the "amazon" (Compras) rule below.
        ("amazon prime", "Contas"), ("google", "Contas"), ("apple.com", "Contas"),
        ("apple com", "Contas"), ("applecombill", "Contas"), ("claude", "Contas"),
        ("anthropic", "Contas"),
        ("openai", "Contas"), ("chatgpt", "Contas"), ("linkedin", "Contas"),
        ("totalpass", "Contas"), ("gympass", "Contas"), ("wellhub", "Contas"),
        ("icloud", "Contas"), ("tokio marine", "Contas"), ("porto seguro", "Contas"),
        ("yelum", "Contas"), ("enel", "Contas"), ("sabesp", "Contas"),
        ("corsan", "Contas"),
        // Vestuário — applies only if the user keeps a "Vestuário" category.
        ("netshoes", "Vestuário"), ("authentic feet", "Vestuário"), ("hmbrasil", "Vestuário"),
        ("cotton on", "Vestuário"), ("meias", "Vestuário"), ("renner", "Vestuário"),
        ("riachuelo", "Vestuário"), ("zara", "Vestuário"), ("nike", "Vestuário"),
        ("adidas", "Vestuário"), ("chosen", "Vestuário"),
        // Compras — generic marketplaces; applies only if a "Compras" category exists.
        ("amazon", "Compras"), ("aliexpress", "Compras"), ("shopee", "Compras"),
        ("shein", "Compras"), ("mercadolivre", "Compras"),
        ("bazar", "Compras"), ("acessorios", "Compras"),
    ]

    /// Resolves a category for a transaction, in priority order:
    /// 1. a learned `MerchantRule` for this merchant,
    /// 2. the built-in seed keyword map,
    /// 3. `suggestedName` — a category the statement itself provided (Itaú).
    ///
    /// Tiers 2 and 3 only apply when a category with that canonical name actually
    /// exists in `categories`.
    static func category(
        forKey merchantKey: String,
        rules: [MerchantRule],
        categories: [Category],
        suggestedName: String? = nil
    ) -> Category? {
        let key = merchantKey.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)

        if let rule = rules.first(where: {
            $0.merchantKey.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) == key
        }), let category = rule.category {
            return category
        }

        let name = seedCategoryName(forKey: key) ?? suggestedName
        guard let name else { return nil }
        return categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The seed category name for a key, or nil. First keyword hit wins.
    static func seedCategoryName(forKey key: String) -> String? {
        let normalized = key.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return seed.first { normalized.contains($0.keyword) }?.category
    }
}
