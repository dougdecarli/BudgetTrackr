import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<IncomeSource> { !$0.isArchived },
        sort: [SortDescriptor(\IncomeSource.label)]
    )
    private var sources: [IncomeSource]

    @State private var editing: IncomeSource?
    @State private var showingCreate = false

    var body: some View {
        List {
            if sources.isEmpty {
                ContentUnavailableView(
                    "Nenhuma fonte de renda",
                    systemImage: "tray",
                    description: Text("Toque em + para adicionar.")
                )
            } else {
                ForEach(sources) { source in
                    Button {
                        editing = source
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.label)
                                    .foregroundStyle(.primary)
                                Text(source.type.displayName)
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
                            source.isArchived = true
                            try? context.save()
                        } label: {
                            Label("Arquivar", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Fontes de renda")
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
            IncomeSourceEditorSheet(source: nil)
        }
        .sheet(item: $editing) { source in
            IncomeSourceEditorSheet(source: source)
        }
    }
}
