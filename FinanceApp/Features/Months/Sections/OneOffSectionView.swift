import SwiftUI
import SwiftData

struct OneOffSectionView: View {
    @Environment(\.modelContext) private var context
    let month: Month
    /// Presented by the parent screen's root so the sheet is never nested.
    var onAdd: () -> Void = {}
    var onEdit: (OneOffExpense) -> Void = { _ in }

    // Queried (rather than read off `month.oneOffs`) so the list refreshes when
    // an expense is added from the sheet presented at the screen root.
    @Query private var allOneOffs: [OneOffExpense]

    private var entries: [OneOffExpense] {
        allOneOffs
            .filter { $0.month?.id == month.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Section {
            if entries.isEmpty {
                Text("Nenhuma despesa avulsa.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(entries) { entry in
                    Button {
                        onEdit(entry)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.label)
                                    .foregroundStyle(.primary)
                                CategoryNameText(entry.category?.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.amount.brl)
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(entry)
                            try? context.save()
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                onAdd()
            } label: {
                Label("Adicionar despesa avulsa", systemImage: "plus.circle")
            }
        } header: {
            Text("Despesas avulsas")
        }
    }
}
