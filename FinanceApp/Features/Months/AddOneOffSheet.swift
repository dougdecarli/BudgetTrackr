import SwiftUI
import SwiftData

struct AddOneOffSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let month: Month
    let onSaved: (OneOffExpense) -> Void

    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    @State private var label: String = ""
    @State private var selectedCategoryID: UUID?
    @State private var amount: Decimal?

    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedCategoryID != nil
            && (amount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Despesa") {
                    TextField("Nome", text: $label)

                    Picker("Categoria", selection: $selectedCategoryID) {
                        Text("Selecione…").tag(UUID?.none)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(cat.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    TextField(
                        "R$ 0,00",
                        value: $amount,
                        format: Money.currencyStyle
                    )
                    .keyboardType(.decimalPad)
                }

                if categories.isEmpty {
                    Section {
                        Text("Crie uma categoria em Ajustes → Categorias antes de continuar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Despesa avulsa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let category = selectedCategory, let amount, amount > 0 else { return }
        let entry = OneOffExpense(
            month: month,
            label: label.trimmingCharacters(in: .whitespaces),
            category: category,
            amount: amount
        )
        context.insert(entry)
        try? context.save()
        onSaved(entry)
        dismiss()
    }
}
