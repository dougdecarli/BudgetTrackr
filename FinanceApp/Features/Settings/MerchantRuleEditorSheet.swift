import SwiftUI
import SwiftData

struct MerchantRuleEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    let rule: MerchantRule

    @State private var merchantKey: String = ""
    @State private var selectedCategoryID: UUID?

    var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }
    var canSave: Bool {
        !merchantKey.trimmingCharacters(in: .whitespaces).isEmpty && selectedCategoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Estabelecimento") {
                    TextField("Nome normalizado", text: $merchantKey)
                        .autocorrectionDisabled()
                }
                Section("Categoria") {
                    Picker("Categoria", selection: $selectedCategoryID) {
                        Text("Selecione…").tag(UUID?.none)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(cat.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("Editar regra")
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
                merchantKey = rule.merchantKey
                selectedCategoryID = rule.category?.id
            }
        }
    }

    private func save() {
        rule.merchantKey = merchantKey.trimmingCharacters(in: .whitespaces)
        rule.category = selectedCategory
        try? context.save()
        dismiss()
    }
}
