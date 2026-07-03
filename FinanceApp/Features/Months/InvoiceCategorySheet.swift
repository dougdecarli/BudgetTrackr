import SwiftUI
import SwiftData

/// Category picker for a single invoice transaction. Tapping a category assigns
/// it and dismisses; a new category can be created inline. The caller persists
/// the choice (and learns the merchant rule).
struct InvoiceCategorySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    let transaction: InvoiceTransaction
    let onSelect: (Category) -> Void

    @State private var creatingCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent {
                        Text(Money.formatSigned(transaction.amount))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.rawDescription)
                                .font(.subheadline.weight(.medium))
                            if transaction.isInstallment {
                                Text("Parcela \(transaction.installmentCurrent)/\(transaction.installmentTotal)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Categoria") {
                    ForEach(categories) { category in
                        Button {
                            onSelect(category)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.tint(for: category.id))
                                CategoryNameText(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if transaction.category?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.income)
                                }
                            }
                        }
                    }

                    Button {
                        creatingCategory = true
                    } label: {
                        Label("Nova categoria", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Categorizar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .alert("Nova categoria", isPresented: $creatingCategory) {
                TextField("Nome", text: $newCategoryName)
                Button("Cancelar", role: .cancel) { newCategoryName = "" }
                Button("Criar", action: createCategory)
            }
        }
    }

    private func createCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        newCategoryName = ""
        guard !trimmed.isEmpty else { return }
        // Reuse a same-named category instead of creating a duplicate.
        let category = categories.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
            ?? {
                let created = Category(name: trimmed)
                context.insert(created)
                try? context.save()
                return created
            }()
        onSelect(category)
        dismiss()
    }
}
