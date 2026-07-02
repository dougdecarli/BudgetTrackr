import SwiftUI

/// Pushed detail screen that hosts one of the existing `*SectionView`s in a
/// `List`. It is a navigation push (not a sheet), so the section views' own
/// "Adicionar" sheets present from the navigation stack without ever stacking
/// a sheet on top of a sheet — which is what triggered the
/// "presentation in progress" error.
struct SectionDetailScreen<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        List {
            content
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
