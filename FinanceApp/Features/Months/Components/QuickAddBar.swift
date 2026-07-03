import SwiftUI

/// Two prominent add actions under the hero. Adding income or an expense used
/// to require: tap a card → push detail → open its sheet. This offers both in
/// one tap, presented from the Meses root (preserving the sheet-from-root
/// contract).
struct QuickAddBar: View {
    let onAddIncome: () -> Void
    let onAddExpense: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            button("Renda", tint: Theme.income, action: onAddIncome)
            button("Despesa", tint: Theme.oneOff, action: onAddExpense)
        }
    }

    private func button(_ title: LocalizedStringKey, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.footnote.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(tint.opacity(0.15))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
