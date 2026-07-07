import SwiftUI
import SwiftData

/// Adds a charge to an invoice by hand — for statements whose line items can't
/// be read automatically (some Itaú "eStatements" layouts), or to fill in a
/// charge the parser missed. Does not touch the invoice's total, which stays the
/// authoritative statement total; a manual charge just adds itemization.
struct AddInvoiceTransactionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let invoice: CreditCardInvoice

    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    @State private var label = ""
    @State private var entry = AmountEntry()
    @State private var selectedCategoryID: UUID?
    @State private var date = Date()
    @State private var creatingCategory = false
    @State private var newCategoryName = ""
    @State private var didSave = false

    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && entry.decimal > 0
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
            VStack(spacing: 16) {
                AmountDisplayView(entry: entry, tint: Theme.card)
                    .padding(.top, 8)

                TextField("Descrição", text: $label)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                DatePicker("Data", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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

                Spacer(minLength: 0)

                AmountKeypad(entry: $entry, tint: Theme.card)
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Novo lançamento")
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
            .alert("Nova categoria", isPresented: $creatingCategory) {
                TextField("Nome", text: $newCategoryName)
                Button("Cancelar", role: .cancel) { newCategoryName = "" }
                Button("Criar", action: createCategory)
            }
            .sensoryFeedback(.success, trigger: didSave)
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
        guard entry.decimal > 0 else { return }
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        context.insert(
            InvoiceTransaction(
                invoice: invoice,
                postedDate: date,
                rawDescription: trimmed,
                merchantKey: NubankInvoiceParser.merchantKey(from: trimmed),
                amount: entry.decimal,
                category: selectedCategory,
                isFee: false
            )
        )
        try? context.save()
        didSave.toggle()
        dismiss()
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
        selectedCategoryID = category.id
    }
}
