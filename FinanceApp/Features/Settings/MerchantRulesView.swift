import SwiftUI
import SwiftData

struct MerchantRulesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MerchantRule.merchantKey)]) private var rules: [MerchantRule]

    @State private var editing: MerchantRule?

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView(
                    "Nenhuma regra",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Regras são criadas automaticamente ao revisar a fatura.")
                )
            } else {
                ForEach(rules) { rule in
                    Button {
                        editing = rule
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.merchantKey).foregroundStyle(.primary)
                                CategoryNameText(rule.category?.name)
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
                        Button(role: .destructive) {
                            context.delete(rule)
                            try? context.save()
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Regras de estabelecimentos")
        .sheet(item: $editing) { rule in
            MerchantRuleEditorSheet(rule: rule)
        }
    }
}
