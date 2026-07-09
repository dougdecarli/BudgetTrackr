import SwiftUI
import SwiftData

struct MerchantRulesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MerchantRule.merchantKey)]) private var rules: [MerchantRule]

    @State private var editing: MerchantRule?
    @State private var searchText = ""

    /// Rules matching the search box, by merchant key or assigned category name.
    private var filteredRules: [MerchantRule] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return rules }
        // localizedStandardContains ignores both case and diacritics, so
        // "saude" matches "Saúde" — how pt-BR users actually type.
        return rules.filter { rule in
            rule.merchantKey.localizedStandardContains(query)
                || (rule.category?.name.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView(
                    "Nenhuma regra",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Regras são criadas automaticamente ao revisar a fatura.")
                )
            } else if filteredRules.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredRules) { rule in
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
        .searchable(text: $searchText, prompt: "Buscar estabelecimento ou categoria")
        .sheet(item: $editing) { rule in
            MerchantRuleEditorSheet(rule: rule)
        }
    }
}
