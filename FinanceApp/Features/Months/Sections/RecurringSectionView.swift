import SwiftUI
import SwiftData

struct RecurringSectionView: View {
    @Environment(\.modelContext) private var context
    let month: Month

    @Query(
        filter: #Predicate<ExpenseTemplate> { !$0.isArchived },
        sort: [SortDescriptor(\ExpenseTemplate.label)]
    )
    private var templates: [ExpenseTemplate]

    @State private var showingHidden = false

    private var skippedIDs: Set<UUID> {
        Set((month.skippedTemplates ?? []).map(\.id))
    }

    private var visibleTemplates: [ExpenseTemplate] {
        templates.filter { !skippedIDs.contains($0.id) }
    }

    private var hiddenTemplates: [ExpenseTemplate] {
        templates.filter { skippedIDs.contains($0.id) }
    }

    var body: some View {
        Section {
            if templates.isEmpty {
                Text("Nenhuma despesa recorrente cadastrada.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(visibleTemplates) { template in
                    RecurringRow(month: month, template: template)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                hide(template)
                            } label: {
                                Label("Remover", systemImage: "trash")
                            }
                        }
                }

                if showingHidden {
                    ForEach(hiddenTemplates) { template in
                        RecurringRow(month: month, template: template)
                            .opacity(0.5)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    unhide(template)
                                } label: {
                                    Label("Restaurar", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                    }
                }

                if !hiddenTemplates.isEmpty {
                    Button {
                        showingHidden.toggle()
                    } label: {
                        Label {
                            if showingHidden {
                                Text("Ocultar removidas")
                            } else {
                                Text("Mostrar \(hiddenTemplates.count) removidas")
                            }
                        } icon: {
                            Image(systemName: showingHidden ? "eye.slash" : "eye")
                        }
                        .font(.caption)
                    }
                }
            }
        } header: {
            Text("Despesas recorrentes")
        }
    }

    private func entry(for template: ExpenseTemplate) -> RecurringExpenseEntry? {
        (month.recurringEntries ?? []).first { $0.template?.id == template.id }
    }

    private func hide(_ template: ExpenseTemplate) {
        if let entry = entry(for: template) {
            context.delete(entry)
        }
        var skipped = month.skippedTemplates ?? []
        if !skipped.contains(where: { $0.id == template.id }) {
            skipped.append(template)
            month.skippedTemplates = skipped
        }
        try? context.save()
    }

    private func unhide(_ template: ExpenseTemplate) {
        var skipped = month.skippedTemplates ?? []
        skipped.removeAll { $0.id == template.id }
        month.skippedTemplates = skipped
        try? context.save()
    }
}

private struct RecurringRow: View {
    @Environment(\.modelContext) private var context
    let month: Month
    let template: ExpenseTemplate

    @State private var amount: Decimal?

    private var existingEntry: RecurringExpenseEntry? {
        (month.recurringEntries ?? []).first { $0.template?.id == template.id }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(template.label)
                    if template.isTicketCard {
                        Image(systemName: "creditcard")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                CategoryNameText(template.category?.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField(
                "R$ 0,00",
                value: $amount,
                format: Money.currencyStyle
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(maxWidth: 140)
        }
        .onAppear {
            amount = existingEntry?.amount
        }
        .onChange(of: amount) { _, newValue in
            persist(newValue)
        }
    }

    private func persist(_ newValue: Decimal?) {
        if let value = newValue, value > 0 {
            if let entry = existingEntry {
                entry.amount = value
            } else {
                context.insert(
                    RecurringExpenseEntry(month: month, template: template, amount: value)
                )
            }
        } else if let entry = existingEntry {
            context.delete(entry)
        }
        try? context.save()
    }
}
