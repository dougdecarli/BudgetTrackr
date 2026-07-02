import SwiftUI

/// Renders a category name, or a localized "no category" placeholder when the
/// name is missing or empty. Using this instead of `name ?? "Sem categoria"`
/// keeps the fallback localizable — a `String` fallback would render verbatim.
struct CategoryNameText: View {
    private let name: String?

    init(_ name: String?) {
        self.name = name
    }

    var body: some View {
        if let name, !name.isEmpty {
            Text(name)
        } else {
            Text("Sem categoria")
        }
    }
}
