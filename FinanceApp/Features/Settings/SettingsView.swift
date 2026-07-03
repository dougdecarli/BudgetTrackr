import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var settings: [AppSettings]
    @State private var showingOnboarding = false

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

            Section {
                if let settings = settings.first {
                    @Bindable var bindable = settings
                    Toggle(isOn: $bindable.emDinheiroEnabled) {
                        Label("Mostrar valor \u{201C}em dinheiro\u{201D}", systemImage: "banknote")
                    }
                }
            } header: {
                Text("Visualização")
            } footer: {
                Text("Adiciona um resumo \u{201C}em dinheiro\u{201D} no topo do mês, que desconsidera benefícios (como vale-refeição) e os gastos pagos com eles — mostrando só o que realmente entra e sai em dinheiro.")
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

            Section {
                Button {
                    showingOnboarding = true
                } label: {
                    Label("Ver tutorial novamente", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("Ajustes")
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView { showingOnboarding = false }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
