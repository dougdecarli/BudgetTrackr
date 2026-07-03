import SwiftUI
import SwiftData

struct IncomeSectionView: View {
    @Environment(\.modelContext) private var context
    let month: Month
    /// Presented by the parent screen's root so the sheet is never nested.
    var onAdd: () -> Void = {}
    var onEdit: (IncomeEntry) -> Void = { _ in }

    // Queried (rather than read off `month.incomeEntries`) so the list refreshes
    // when an entry is added from the sheet presented at the screen root.
    @Query private var allIncomeEntries: [IncomeEntry]

    private var entries: [IncomeEntry] {
        allIncomeEntries
            .filter { $0.month?.id == month.id }
            .sorted { ($0.source?.label ?? "") < ($1.source?.label ?? "") }
    }

    var body: some View {
        Section {
            if entries.isEmpty {
                Text("Nenhuma renda registrada.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(entries) { entry in
                    Button {
                        onEdit(entry)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.source?.label ?? "—")
                                    .foregroundStyle(.primary)
                                Text(entry.source?.type.displayName ?? "")
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
                Label("Adicionar renda", systemImage: "plus.circle")
            }
        } header: {
            Text("Renda")
        }
    }
}
