import SwiftUI

/// Horizontal, single-select chip row that replaces the drill-in `Picker`s in
/// the add flows. Each chip carries its own icon + tint; an optional trailing
/// action chip (e.g. "New source") lets the user create an option inline.
struct ChipPicker: View {
    @Environment(\.locale) private var locale

    struct Chip: Identifiable {
        let id: UUID
        let label: String
        let systemImage: String
        let tint: Color
    }

    struct TrailingAction {
        let label: LocalizedStringKey
        let systemImage: String
        let action: () -> Void
    }

    let chips: [Chip]
    @Binding var selection: UUID?
    /// Localize chip labels as keys (used for default category names). Off for
    /// user data like income source labels.
    var localizesLabels: Bool = false
    var trailing: TrailingAction? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    chipView(chip)
                }
                if let trailing {
                    Button(action: trailing.action) {
                        pill(
                            systemImage: trailing.systemImage,
                            content: Text(trailing.label),
                            foreground: Color.accentColor,
                            fill: Color.accentColor.opacity(0.14),
                            stroke: .clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func chipView(_ chip: Chip) -> some View {
        let selected = chip.id == selection
        let label = localizesLabels
            ? Text(CategoryLocalization.display(chip.label, locale: locale))
            : Text(chip.label)
        return Button {
            selection = selected ? nil : chip.id
        } label: {
            pill(
                systemImage: chip.systemImage,
                content: label.lineLimit(1),
                foreground: selected ? chip.tint : .secondary,
                fill: selected ? chip.tint.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                stroke: selected ? chip.tint : .clear
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func pill<Content: View>(
        systemImage: String,
        content: Content,
        foreground: Color,
        fill: Color,
        stroke: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            content
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(foreground)
        .background(Capsule().fill(fill))
        .overlay(Capsule().stroke(stroke, lineWidth: 1))
    }
}
