import SwiftUI
import SwiftData

struct ArchivedItemsView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<IncomeSource> { $0.isArchived },
        sort: [SortDescriptor(\IncomeSource.label)]
    )
    private var archivedSources: [IncomeSource]

    @Query(
        filter: #Predicate<ExpenseTemplate> { $0.isArchived },
        sort: [SortDescriptor(\ExpenseTemplate.label)]
    )
    private var archivedTemplates: [ExpenseTemplate]

    @State private var pendingDelete: PendingDelete?

    private enum PendingDelete: Identifiable {
        case source(IncomeSource)
        case template(ExpenseTemplate)

        var id: UUID {
            switch self {
            case .source(let source): return source.id
            case .template(let template): return template.id
            }
        }
    }

    var body: some View {
        List {
            if archivedSources.isEmpty && archivedTemplates.isEmpty {
                ContentUnavailableView(
                    "Nada arquivado",
                    systemImage: "archivebox",
                    description: Text("Itens arquivados aparecem aqui para restauração.")
                )
            }

            if !archivedSources.isEmpty {
                Section("Fontes de renda") {
                    ForEach(archivedSources) { source in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.label)
                                Text(source.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restaurar") {
                                source.isArchived = false
                                try? context.save()
                            }
                            .buttonStyle(.borderless)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDelete = .source(source)
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !archivedTemplates.isEmpty {
                Section("Despesas recorrentes") {
                    ForEach(archivedTemplates) { template in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(template.label)
                                CategoryNameText(template.category?.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restaurar") {
                                template.isArchived = false
                                try? context.save()
                            }
                            .buttonStyle(.borderless)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDelete = .template(template)
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Arquivados")
        .confirmationDialog(
            "Excluir permanentemente?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { item in
            Button("Excluir", role: .destructive) {
                delete(item)
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text("O item e seus lançamentos serão removidos. Esta ação não pode ser desfeita.")
        }
    }

    /// Permanently removes the item together with its entries, so no orphaned
    /// income/recurring rows are left counting toward past-month totals.
    private func delete(_ item: PendingDelete) {
        switch item {
        case .source(let source):
            for entry in source.entries ?? [] {
                context.delete(entry)
            }
            context.delete(source)
        case .template(let template):
            for entry in template.entries ?? [] {
                context.delete(entry)
            }
            context.delete(template)
        }
        try? context.save()
    }
}
