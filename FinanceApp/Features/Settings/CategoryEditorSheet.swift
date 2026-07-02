import SwiftUI
import SwiftData

struct CategoryEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [Category]

    let category: Category?

    @State private var name: String = ""
    @State private var duplicateWarning = false

    var isEditing: Bool { category != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Ex: Mercado", text: $name)
                        .autocorrectionDisabled()
                }
                if duplicateWarning {
                    Section {
                        Text("Já existe uma categoria com esse nome.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar categoria" : "Nova categoria")
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
                if let category { name = category.name }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        let collision = existing.first {
            $0.name.lowercased() == lower && $0.id != category?.id
        }
        if collision != nil {
            duplicateWarning = true
            return
        }
        if let category {
            category.name = trimmed
        } else {
            context.insert(Category(name: trimmed))
        }
        try? context.save()
        dismiss()
    }
}
