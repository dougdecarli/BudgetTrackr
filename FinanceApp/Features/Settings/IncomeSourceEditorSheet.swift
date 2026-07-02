import SwiftUI
import SwiftData

struct IncomeSourceEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let source: IncomeSource?

    @State private var label: String = ""
    @State private var type: IncomeType = .income

    var isEditing: Bool { source != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informações") {
                    TextField("Nome", text: $label)
                    Picker("Tipo", selection: $type) {
                        ForEach(IncomeType.selectableCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar fonte" : "Nova fonte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let source {
                    label = source.label
                    type = source.type
                }
            }
        }
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if let source {
            source.label = trimmed
            source.type = type
        } else {
            let new = IncomeSource(label: trimmed, type: type)
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}
