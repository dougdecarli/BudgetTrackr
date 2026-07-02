import Foundation
import SwiftUI

/// The UI language the app displays in. `.system` follows the device language;
/// the other cases force a specific language regardless of the device setting.
/// Only the UI copy is affected — currency and month labels stay Brazilian
/// (see `Money` and `DateExtensions`, which pin their own `pt_BR` locale).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case portuguese
    case english

    var id: String { rawValue }

    /// The locale to inject into the SwiftUI environment. `.system` uses the
    /// auto-updating current locale, which is SwiftUI's default behavior.
    var resolvedLocale: Locale {
        switch self {
        case .system:     return .autoupdatingCurrent
        case .portuguese: return Locale(identifier: "pt-BR")
        case .english:    return Locale(identifier: "en")
        }
    }

    /// Whether the effective UI presentation is English. Drives the currency
    /// symbol ($ vs R$). For `.system`, reflects the device language.
    var isEnglishPresentation: Bool {
        switch self {
        case .english:    return true
        case .portuguese: return false
        case .system:     return Locale.autoupdatingCurrent.language.languageCode?.identifier == "en"
        }
    }

    /// Label shown in the Settings picker. Language endonyms ("Português",
    /// "English") are intentionally shown in their own language.
    var pickerLabel: LocalizedStringKey {
        switch self {
        case .system:     return "Automático (sistema)"
        case .portuguese: return "Português"
        case .english:    return "English"
        }
    }
}
