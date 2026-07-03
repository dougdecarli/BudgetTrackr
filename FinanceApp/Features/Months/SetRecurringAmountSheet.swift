import SwiftUI
import SwiftData

/// Sets a recurring template's amount for a given month using the same
/// keypad-driven presentation as `AddIncomeSheet`, replacing the inline list
/// TextField so recurring editing matches income editing.
struct SetRecurringAmountSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let month: Month
    let template: ExpenseTemplate

    @State private var entry = AmountEntry()
    @State private var didSave = false

    private var existingEntry: RecurringExpenseEntry? {
        (month.recurringEntries ?? []).first { $0.template?.id == template.id }
    }

    private var canSave: Bool { entry.decimal > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AmountDisplayView(entry: entry, tint: Theme.recurring)
                    .padding(.top, 8)

                templateHeader

                Spacer(minLength: 0)

                AmountKeypad(entry: $entry, tint: Theme.recurring)
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Despesa recorrente")
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
            .onAppear {
                entry = AmountEntry(existingEntry?.amount)
            }
        }
    }

    private var templateHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.recurring)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(template.label)
                    .font(.body.weight(.medium))
                CategoryNameText(template.category?.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if template.isTicketCard {
                Image(systemName: "creditcard")
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func save() {
        guard entry.decimal > 0 else { return }
        if let existingEntry {
            existingEntry.amount = entry.decimal
        } else {
            context.insert(
                RecurringExpenseEntry(month: month, template: template, amount: entry.decimal)
            )
        }
        // Setting an amount un-hides a template that had been skipped this month.
        if var skipped = month.skippedTemplates, skipped.contains(where: { $0.id == template.id }) {
            skipped.removeAll { $0.id == template.id }
            month.skippedTemplates = skipped
        }
        try? context.save()
        didSave.toggle()
        dismiss()
    }
}
