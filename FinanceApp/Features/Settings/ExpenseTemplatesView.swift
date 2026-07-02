import SwiftUI
import SwiftData

struct ExpenseTemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<ExpenseTemplate> { !$0.isArchived },
        sort: [SortDescriptor(\ExpenseTemplate.label)]
    )
    private var templates: [ExpenseTemplate]

    @State private var editing: ExpenseTemplate?
    @State private var showingCreate = false

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(
                    "Nenhuma despesa recorrente",
                    systemImage: "repeat",
                    description: Text("Toque em + para adicionar.")
                )
            } else {
                ForEach(templates) { template in
                    Button {
                        editing = template
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(template.label)
                                        .foregroundStyle(.primary)
                                    if template.isTicketCard {
                                        Image(systemName: "creditcard")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                CategoryNameText(template.category?.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            template.isArchived = true
                            try? context.save()
                        } label: {
                            Label("Arquivar", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Despesas recorrentes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            ExpenseTemplateEditorSheet(template: nil)
        }
        .sheet(item: $editing) { template in
            ExpenseTemplateEditorSheet(template: template)
        }
    }
}
