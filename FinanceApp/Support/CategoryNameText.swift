import SwiftUI

/// Renders a category name, or a localized "no category" placeholder when the
/// name is missing or empty. Default (seeded) category names are translated for
/// display via `CategoryLocalization`; custom names show verbatim.
struct CategoryNameText: View {
    @Environment(\.locale) private var locale
    private let name: String?

    init(_ name: String?) {
        self.name = name
    }

    var body: some View {
        if let name, !name.isEmpty {
            Text(CategoryLocalization.display(name, locale: locale))
        } else {
            Text("Sem categoria")
        }
    }
}
