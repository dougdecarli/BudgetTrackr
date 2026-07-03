import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    @State private var editing: Category?
    @State private var showingCreate = false
    @State private var blockedDeletion: BlockedDeletion?

    var body: some View {
        List {
            if categories.isEmpty {
                ContentUnavailableView(
                    "Nenhuma categoria",
                    systemImage: "tag",
                    description: Text("Toque em + para adicionar.")
                )
            } else {
                ForEach(categories) { category in
                    Button {
                        editing = category
                    } label: {
                        HStack {
                            CategoryNameText(category.name).foregroundStyle(.primary)
                            Spacer()
                            if category.referenceCount > 0 {
                                Text("\(category.referenceCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            attemptDelete(category)
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Categorias")
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
            CategoryEditorSheet(category: nil)
        }
        .sheet(item: $editing) { category in
            CategoryEditorSheet(category: category)
        }
        .alert(item: $blockedDeletion) { blocked in
            Alert(
                title: Text("Não é possível excluir"),
                message: Text("\u{201C}\(blocked.name)\u{201D} está em uso por \(blocked.count) item(s). Remova as referências antes de excluir."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func attemptDelete(_ category: Category) {
        if category.referenceCount > 0 {
            blockedDeletion = BlockedDeletion(name: category.name, count: category.referenceCount)
        } else {
            context.delete(category)
            try? context.save()
        }
    }
}

private struct BlockedDeletion: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}
