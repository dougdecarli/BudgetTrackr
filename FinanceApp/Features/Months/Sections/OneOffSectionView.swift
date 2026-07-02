import SwiftUI
import SwiftData

struct OneOffSectionView: View {
    @Environment(\.modelContext) private var context
    let month: Month
    /// Presented by the parent screen's root so the sheet is never nested.
    var onAdd: () -> Void = {}

    private var entries: [OneOffExpense] {
        (month.oneOffs ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Section {
            if entries.isEmpty {
                Text("Nenhuma despesa avulsa.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.label)
                            CategoryNameText(entry.category?.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount.brl)
                            .monospacedDigit()
                    }
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
