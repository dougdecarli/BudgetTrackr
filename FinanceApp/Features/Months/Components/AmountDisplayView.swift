import SwiftUI

/// Big, centered amount that headlines the add flows. Reads its value from an
/// `AmountEntry` so it shows exactly what's being typed (including a trailing
/// separator) instead of a reformatted number. A blinking caret makes it clear
/// this is the active input driven by the keypad below.
struct AmountDisplayView: View {
    let entry: AmountEntry
    var caption: LocalizedStringKey = "Valor"
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 4) {
                Text(entry.display)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(entry.isEmpty ? Color.secondary : tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: entry.display)
                BlinkingCaret(color: tint)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Thin caret that fades in and out, mimicking a text-field cursor for the
/// custom keypad (which has no system caret of its own).
private struct BlinkingCaret: View {
    var color: Color
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(width: 3, height: 34)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
            .accessibilityHidden(true)
    }
}
