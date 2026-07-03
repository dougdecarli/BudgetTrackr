import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()
    var emDinheiroEnabled: Bool = false
    /// Whether the first-launch onboarding carousel has been completed (or
    /// skipped). Defaults to `false` — required for CloudKit compatibility — so
    /// a brand-new install shows the tutorial once. Synced across devices via
    /// the `AppSettings` singleton, so it won't reappear on a second device.
    var hasCompletedOnboarding: Bool = false
    /// Persisted raw value of the selected UI language. Stored as a String (not
    /// the enum) so it stays CloudKit-compatible and tolerant of unknown values.
    /// Read/write through `language`.
    var languageRaw: String = AppLanguage.system.rawValue

    /// One-time flag: whether the Vestuário/Compras categories have been
    /// back-filled into an existing install (fresh installs get them via the
    /// default seed). Gated so a category the user later deletes won't reappear.
    var hasSeededShoppingCategories: Bool = false

    /// Selected UI language, backed by `languageRaw`. Falls back to `.system`
    /// for any unrecognized stored value.
    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), emDinheiroEnabled: Bool = false, hasCompletedOnboarding: Bool = false) {
        self.id = id
        self.emDinheiroEnabled = emDinheiroEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
