import SwiftUI
import SwiftData

struct ExpenseTemplateEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    let template: ExpenseTemplate?

    @State private var label: String = ""
    @State private var selectedCategoryID: UUID?
    @State private var isTicketCard: Bool = false

    var isEditing: Bool { template != nil }
    var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }
    var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && selectedCategoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informações") {
                    TextField("Nome", text: $label)

                    Picker("Categoria", selection: $selectedCategoryID) {
                        Text("Selecione…").tag(UUID?.none)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(cat.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Toggle(isOn: $isTicketCard) {
                        Label("Cartão alimentação/refeição", systemImage: "creditcard")
                    }
                }

                if categories.isEmpty {
                    Section {
                        Text("Crie uma categoria em Ajustes → Categorias antes de continuar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar despesa" : "Nova despesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save).disabled(!canSave)
                }
            }
            .onAppear {
                if let template {
                    label = template.label
                    selectedCategoryID = template.category?.id
                    isTicketCard = template.isTicketCard
                }
            }
        }
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if let template {
            template.label = trimmed
            template.category = selectedCategory
            template.isTicketCard = isTicketCard
        } else {
            let new = ExpenseTemplate(
                label: trimmed,
                category: selectedCategory,
                isTicketCard: isTicketCard
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}
