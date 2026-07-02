import SwiftUI
import SwiftData

struct AddIncomeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let month: Month
    /// When set, the sheet edits this entry instead of creating a new one.
    var editing: IncomeEntry? = nil

    @Query(
        filter: #Predicate<IncomeSource> { !$0.isArchived },
        sort: [SortDescriptor(\IncomeSource.label)]
    )
    private var allSources: [IncomeSource]

    @State private var selectedSourceID: UUID?
    @State private var amount: Decimal?

    private var availableSources: [IncomeSource] {
        let usedIDs = Set((month.incomeEntries ?? []).compactMap { $0.source?.id })
        // Keep the edited entry's own source selectable even though it's "used".
        return allSources.filter { !usedIDs.contains($0.id) || $0.id == editing?.source?.id }
    }

    private var selectedSource: IncomeSource? {
        availableSources.first { $0.id == selectedSourceID }
    }

    private var canSave: Bool {
        selectedSourceID != nil && (amount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fonte") {
                    if availableSources.isEmpty {
                        Text("Todas as fontes ativas já foram adicionadas neste mês.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Fonte", selection: $selectedSourceID) {
                            Text("Selecione…").tag(UUID?.none)
                            ForEach(availableSources) { src in
                                Text(src.label).tag(src.id as UUID?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                Section("Valor") {
                    TextField(
                        "R$ 0,00",
                        value: $amount,
                        format: Money.currencyStyle
                    )
                    .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(editing == nil ? "Adicionar renda" : "Editar renda")
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
                if let editing {
                    selectedSourceID = editing.source?.id
                    amount = editing.amount
                }
            }
        }
    }

    private func save() {
        guard let source = selectedSource, let amount, amount > 0 else { return }
        if let editing {
            editing.source = source
            editing.amount = amount
        } else {
            context.insert(IncomeEntry(month: month, source: source, amount: amount))
        }
        try? context.save()
        dismiss()
    }
}
