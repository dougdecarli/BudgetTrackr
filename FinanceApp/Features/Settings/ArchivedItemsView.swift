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
                    }
                }
            }
        }
        .navigationTitle("Arquivados")
    }
}
