import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var settings: [AppSettings]

    var body: some View {
        Form {
            Section("Cadastros") {
                NavigationLink {
                    IncomeSourcesView()
                } label: {
                    Label("Fontes de renda", systemImage: "tray.and.arrow.down")
                }
                NavigationLink {
                    ExpenseTemplatesView()
                } label: {
                    Label("Despesas recorrentes", systemImage: "repeat")
                }
                NavigationLink {
                    CategoriesView()
                } label: {
                    Label("Categorias", systemImage: "tag")
                }
                NavigationLink {
                    MerchantRulesView()
                } label: {
                    Label("Regras de estabelecimentos", systemImage: "list.bullet.rectangle")
                }
            }

            Section("Visualização") {
                if let settings = settings.first {
                    @Bindable var bindable = settings
                    Toggle(isOn: $bindable.emDinheiroEnabled) {
                        Label("Mostrar valor \u{201C}em dinheiro\u{201D}", systemImage: "banknote")
                    }
                }
            }

            Section("Idioma") {
                if let settings = settings.first {
                    let bindable = settings
                    Picker(
                        selection: Binding(
                            get: { bindable.language },
                            set: { bindable.language = $0 }
                        )
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.pickerLabel).tag(language)
                        }
                    } label: {
                        Label("Idioma", systemImage: "globe")
                    }
                }
            }

            Section {
                NavigationLink {
                    ArchivedItemsView()
                } label: {
                    Label("Arquivados", systemImage: "archivebox")
                }
            }
        }
        .navigationTitle("Ajustes")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
