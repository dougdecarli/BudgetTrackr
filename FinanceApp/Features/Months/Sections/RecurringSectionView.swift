import SwiftUI
import SwiftData

struct RecurringSectionView: View {
    @Environment(\.modelContext) private var context
    let month: Month
    /// Presented by the parent screen's root so the sheet is never nested.
    var onEdit: (ExpenseTemplate) -> Void = { _ in }

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
                    RecurringRow(month: month, template: template, onEdit: onEdit)
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
                        RecurringRow(month: month, template: template, onEdit: onEdit)
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
    let month: Month
    let template: ExpenseTemplate
    let onEdit: (ExpenseTemplate) -> Void

    private var existingEntry: RecurringExpenseEntry? {
        (month.recurringEntries ?? []).first { $0.template?.id == template.id }
    }

    var body: some View {
        Button {
            onEdit(template)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text(template.label)
                            .foregroundStyle(.primary)
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
                if let amount = existingEntry?.amount {
                    Text(amount.brl)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else {
                    Text("Definir")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
