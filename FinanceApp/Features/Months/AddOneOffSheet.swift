import SwiftUI
import SwiftData

struct AddOneOffSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let month: Month
    /// When set, the sheet edits this expense instead of creating a new one.
    var editing: OneOffExpense? = nil

    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    @Query(
        filter: #Predicate<ExpenseTemplate> { !$0.isArchived },
        sort: [SortDescriptor(\ExpenseTemplate.label)]
    )
    private var templates: [ExpenseTemplate]

    @State private var label: String = ""
    @State private var selectedCategoryID: UUID?
    @State private var entry = AmountEntry()
    @State private var saveAsRecurring = false
    @State private var creatingCategory = false
    @State private var didSave = false
    @FocusState private var nameFocused: Bool

    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedCategoryID != nil
            && entry.decimal > 0
    }

    private var chips: [ChipPicker.Chip] {
        categories.map { category in
            ChipPicker.Chip(
                id: category.id,
                label: category.name,
                systemImage: "tag.fill",
                tint: Theme.tint(for: category.id)
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                AmountDisplayView(entry: entry, tint: Theme.oneOff, showsCaret: !nameFocused)
                    .padding(.top, 8)
                    .contentShape(Rectangle())
                    // Tapping the value returns from the name field to the keypad.
                    .onTapGesture { nameFocused = false }

                TextField("Nome", text: $label)
                    .focused($nameFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Categoria")
                    if categories.isEmpty {
                        emptyCategories
                    } else {
                        ChipPicker(
                            chips: chips,
                            selection: $selectedCategoryID,
                            localizesLabels: true,
                            trailing: .init(label: "Nova categoria", systemImage: "plus") {
                                creatingCategory = true
                            }
                        )
                    }
                }

                if editing == nil {
                    Toggle("Salvar como recorrente", isOn: $saveAsRecurring)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                }

                Spacer(minLength: 0)

                // The custom keypad and the system keyboard are mutually
                // exclusive input surfaces: hide the keypad while the name field
                // is focused so only one keyboard is ever on screen.
                if !nameFocused {
                    AmountKeypad(entry: $entry, tint: Theme.oneOff)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
            .animation(.snappy(duration: 0.25), value: nameFocused)
            // Keep the system keyboard from compressing the layout (which slid
            // the value up under the nav title); it overlays the hidden keypad.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(editing == nil ? "Adicionar despesa" : "Editar despesa")
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
            .navigationDestination(isPresented: $creatingCategory) {
                NewCategoryView { newCategory in
                    selectedCategoryID = newCategory.id
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
            .onAppear {
                if let editing {
                    label = editing.label
                    selectedCategoryID = editing.category?.id
                    entry = AmountEntry(editing.amount)
                }
            }
        }
    }

    private var emptyCategories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nenhuma categoria ainda.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                creatingCategory = true
            } label: {
                Label("Nova categoria", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func save() {
        guard let category = selectedCategory, entry.decimal > 0 else { return }
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        let amount = entry.decimal

        if let editing {
            editing.label = trimmed
            editing.category = category
            editing.amount = amount
        } else if saveAsRecurring {
            // Recurring: record it under this month's recurring expenses (via a
            // template + entry) rather than as a one-off, and let the template
            // carry it into future months.
            let template = templates.first { $0.label.caseInsensitiveCompare(trimmed) == .orderedSame }
                ?? insertTemplate(label: trimmed, category: category)
            if let existing = (month.recurringEntries ?? []).first(where: { $0.template?.id == template.id }) {
                existing.amount = amount
            } else {
                context.insert(RecurringExpenseEntry(month: month, template: template, amount: amount))
            }
            unhide(template)
        } else {
            context.insert(
                OneOffExpense(month: month, label: trimmed, category: category, amount: amount)
            )
        }

        try? context.save()
        didSave.toggle()
        dismiss()
    }

    private func insertTemplate(label: String, category: Category) -> ExpenseTemplate {
        let template = ExpenseTemplate(label: label, category: category, isTicketCard: false)
        context.insert(template)
        return template
    }

    private func unhide(_ template: ExpenseTemplate) {
        guard var skipped = month.skippedTemplates,
              skipped.contains(where: { $0.id == template.id }) else { return }
        skipped.removeAll { $0.id == template.id }
        month.skippedTemplates = skipped
    }
}

/// Minimal inline category creator, pushed within the sheet's own navigation
/// stack (a push, not a nested sheet) so adding an expense mirrors adding
/// income, where a source can be created on the fly.
private struct NewCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Category.name)]) private var existing: [Category]
    let onCreate: (Category) -> Void

    @State private var name = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Ex: Mercado", text: $name)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle("Nova categoria")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar", action: save)
                    .disabled(!canSave)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // Reuse a same-named category instead of creating a duplicate (which the
        // dedup pass would later merge away, dropping the just-made selection).
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            onCreate(match)
        } else {
            let category = Category(name: trimmed)
            context.insert(category)
            try? context.save()
            onCreate(category)
        }
        dismiss()
    }
}
