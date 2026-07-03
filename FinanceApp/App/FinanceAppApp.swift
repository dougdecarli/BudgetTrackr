import SwiftUI
import SwiftData

@main
struct FinanceAppApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppSettings.self,
            IncomeSource.self,
            Category.self,
            ExpenseTemplate.self,
            MerchantRule.self,
            Month.self,
            IncomeEntry.self,
            RecurringExpenseEntry.self,
            OneOffExpense.self,
            CreditCardInvoice.self,
            InvoiceCategoryTotal.self,
        ])

        // `.automatic` enables iCloud sync when the app has an iCloud/CloudKit
        // entitlement configured (Xcode → Signing & Capabilities → iCloud →
        // CloudKit), and falls back to local-only storage otherwise.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        // Try the CloudKit-backed store first. If it can't be created (e.g. the
        // entitlement isn't set up yet, or CloudKit is unavailable), fall back
        // to a purely local store so the app still launches instead of crashing.
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            Self.bootstrap(container.mainContext)
            return container
        }

        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [localConfig])
            Self.bootstrap(container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func bootstrap(_ context: ModelContext) {
        // AppSettings is a singleton. Sort by id so all devices agree on which
        // record to keep, then drop any extras that may have arrived via iCloud
        // sync (two devices can each create their own before they reconcile).
        let descriptor = FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.id)])
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            // Very first launch: create the settings singleton and seed a
            // starter set of categories so a new user can log an expense right
            // away without having to create categories first.
            context.insert(AppSettings())
            seedDefaultCategories(context)
            try? context.save()
        } else if existing.count > 1 {
            for duplicate in existing.dropFirst() {
                context.delete(duplicate)
            }
            try? context.save()
        }
    }

    private static func seedDefaultCategories(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        // Stored as the canonical (pt-BR) key; the UI localizes it at display
        // time via `Text(LocalizedStringKey:)`, so these follow the app's
        // language switch. The user can still rename or delete them.
        let defaults = ["Moradia", "Alimentação", "Transporte", "Saúde", "Educação", "Lazer", "Mercado", "Contas"]
        for name in defaults {
            context.insert(Category(name: name))
        }
    }
}

/// Applies the user-selected UI language by overriding the environment locale,
/// which is what SwiftUI uses to resolve localized `Text`/`Label` strings. Reads
/// the choice from `AppSettings` so it updates live when changed in Settings.
private struct RootView: View {
    @Query private var settings: [AppSettings]

    private var language: AppLanguage {
        settings.first?.language ?? .system
    }

    var body: some View {
        let language = self.language
        // Currency presentation follows the same choice as the UI language.
        Money.usesEnglish = language.isEnglishPresentation
        return RootTabView()
            .environment(\.locale, language.resolvedLocale)
    }
}
