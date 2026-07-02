import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()
    var emDinheiroEnabled: Bool = false
    /// Persisted raw value of the selected UI language. Stored as a String (not
    /// the enum) so it stays CloudKit-compatible and tolerant of unknown values.
    /// Read/write through `language`.
    var languageRaw: String = AppLanguage.system.rawValue

    /// Selected UI language, backed by `languageRaw`. Falls back to `.system`
    /// for any unrecognized stored value.
    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), emDinheiroEnabled: Bool = false) {
        self.id = id
        self.emDinheiroEnabled = emDinheiroEnabled
    }
}
