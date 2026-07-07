import SwiftUI

/// Corrects the amount of a single invoice line when the PDF parse got it wrong.
/// Uses the same custom keypad as the add flows; the caller persists the new
/// value and re-totals the invoice.
struct EditInvoiceAmountSheet: View {
    @Environment(\.dismiss) private var dismiss

    let transaction: InvoiceTransaction
    let onSave: (Decimal) -> Void

    @State private var entry: AmountEntry
    @State private var didSave = false

    init(transaction: InvoiceTransaction, onSave: @escaping (Decimal) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        // Amounts are stored signed (credits are negative); the keypad edits the
        // magnitude and the sign is restored on save.
        _entry = State(initialValue: AmountEntry(abs(transaction.amount)))
    }

    private var canSave: Bool { entry.decimal > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(transaction.rawDescription)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if transaction.isInstallment {
                        Text("Parcela \(transaction.installmentCurrent)/\(transaction.installmentTotal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                AmountDisplayView(entry: entry, tint: Theme.card)

                Spacer(minLength: 0)

                AmountKeypad(entry: $entry, tint: Theme.card)
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Editar valor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
        }
    }

    private func save() {
        guard entry.decimal > 0 else { return }
        // Preserve the original sign so credits/refunds stay negative.
        let magnitude = entry.decimal
        let signed = transaction.amount < 0 ? -magnitude : magnitude
        onSave(signed)
        didSave.toggle()
        dismiss()
    }
}
