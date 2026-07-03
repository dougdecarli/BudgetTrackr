import Foundation

/// Translates category names (and the "Outros" / "Sem categoria" placeholders)
/// for display.
///
/// Category names are stored as their canonical pt-BR key. Rendering them with
/// `Text(LocalizedStringKey(runtimeString))` is unreliable — SwiftUI does not
/// consistently resolve a *runtime* key against the injected `\.locale`. Instead
/// we look the key up explicitly in the English string table when the UI is in
/// English, and otherwise return the raw (already Portuguese) name.
enum CategoryLocalization {
    private static let englishBundle: Bundle? = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }()

    /// The name to show for `locale`. Only English is translated; every other
    /// language (including the pt-BR source and `.system` on a non-English
    /// device) shows the stored name as-is.
    static func display(_ name: String, locale: Locale) -> String {
        guard locale.language.languageCode?.identifier == "en",
              let bundle = englishBundle else {
            return name
        }
        return bundle.localizedString(forKey: name, value: name, table: nil)
    }
}
