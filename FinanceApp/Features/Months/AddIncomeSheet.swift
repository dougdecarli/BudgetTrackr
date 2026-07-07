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
    @State private var entry = AmountEntry()
    @State private var creatingSource = false
    @State private var didSave = false

    private var availableSources: [IncomeSource] {
        let usedIDs = Set((month.incomeEntries ?? []).compactMap { $0.source?.id })
        // Keep the edited entry's own source selectable even though it's "used".
        return allSources.filter { !usedIDs.contains($0.id) || $0.id == editing?.source?.id }
    }

    private var selectedSource: IncomeSource? {
        availableSources.first { $0.id == selectedSourceID }
    }

    private var canSave: Bool {
        selectedSourceID != nil && entry.decimal > 0
    }

    private var chips: [ChipPicker.Chip] {
        availableSources.map { src in
            ChipPicker.Chip(
                id: src.id,
                label: src.label,
                systemImage: Self.icon(for: src.type),
                tint: Self.tint(for: src.type)
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AmountDisplayView(entry: entry, tint: Theme.income)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Fonte")
                    if availableSources.isEmpty {
                        emptySources
                    } else {
                        ChipPicker(
                            chips: chips,
                            selection: $selectedSourceID,
                            trailing: .init(label: "Nova fonte", systemImage: "plus") {
                                creatingSource = true
                            }
                        )
                    }
                }

                Spacer(minLength: 0)

                AmountKeypad(entry: $entry, tint: Theme.income)
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(editing == nil ? "Adicionar renda" : "Editar renda")
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
            .navigationDestination(isPresented: $creatingSource) {
                NewIncomeSourceView { newSource in
                    selectedSourceID = newSource.id
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
            .onAppear {
                if let editing {
                    selectedSourceID = editing.source?.id
                    entry = AmountEntry(editing.amount)
                }
            }
        }
    }

    private var emptySources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Todas as fontes ativas já foram adicionadas neste mês.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                creatingSource = true
            } label: {
                Label("Nova fonte", systemImage: "plus")
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
        guard let source = selectedSource, entry.decimal > 0 else { return }
        let amount = entry.decimal
        if let editing {
            editing.source = source
            editing.amount = amount
        } else {
            context.insert(IncomeEntry(month: month, source: source, amount: amount))
        }
        try? context.save()
        didSave.toggle()
        dismiss()
    }

    private static func icon(for type: IncomeType) -> String {
        switch type {
        case .income:  return "briefcase.fill"
        case .bonus:   return "sparkles"
        case .benefit: return "gift.fill"
        case .tax:     return "building.columns.fill"
        case .other:   return "square.grid.2x2.fill"
        }
    }

    private static func tint(for type: IncomeType) -> Color {
        switch type {
        case .income:  return .green
        case .bonus:   return .orange
        case .benefit: return .teal
        case .tax:     return .red
        case .other:   return .indigo
        }
    }
}

/// Minimal inline source creator, pushed within the sheet's own navigation
/// stack (a push, not a nested sheet) so the add-income flow never dead-ends
/// when every existing source is already used this month.
private struct NewIncomeSourceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let onCreate: (IncomeSource) -> Void

    @State private var label = ""
    @State private var type: IncomeType = .income

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Fonte") {
                TextField("Nome", text: $label)
                Picker("Tipo", selection: $type) {
                    ForEach(IncomeType.selectableCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }
        }
        .navigationTitle("Nova fonte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    let source = IncomeSource(
                        label: label.trimmingCharacters(in: .whitespaces),
                        type: type
                    )
                    context.insert(source)
                    try? context.save()
                    onCreate(source)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }
}
