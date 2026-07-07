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
            InvoiceTransaction.self,
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

        // Runs every launch: repairs legacy/synced data where a default
        // category was stored under its English display name instead of the
        // canonical pt-BR key.
        normalizeDefaultCategoryNames(context)

        // One-time back-fill of the shopping-related categories for installs that
        // predate them (fresh installs already get them from the default seed).
        backfillShoppingCategories(context)
    }

    private static let shoppingCategories = ["Compras"]

    /// Inserts the shopping-related categories once, if missing, for an existing
    /// install. Gated on an `AppSettings` flag so a category the user later
    /// deletes does not reappear on the next launch.
    private static func backfillShoppingCategories(_ context: ModelContext) {
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.id)])))?.first
        guard let settings, !settings.hasSeededShoppingCategories else { return }

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let present = Set(categories.map { $0.name.lowercased() })
        for name in shoppingCategories where !present.contains(name.lowercased()) {
            context.insert(Category(name: name))
        }
        settings.hasSeededShoppingCategories = true
        try? context.save()
    }

    /// Reverse of `CategoryLocalization`'s pt-BR→English map. Default category
    /// names must be stored as the canonical pt-BR key so the UI can localize
    /// them at display time; a name stored in English would otherwise show up in
    /// English even when the app language is Portuguese.
    private static let englishToCanonicalCategory: [String: String] = [
        "Housing": "Moradia",
        "Food": "Alimentação",
        "Transport": "Transporte",
        "Health": "Saúde",
        "Education": "Educação",
        "Leisure": "Lazer",
        "Groceries": "Mercado",
        "Bills": "Contas",
        "Clothing": "Vestuário",
        "Shopping": "Compras",
    ]

    /// Rewrites any default category stored under its English name back to the
    /// canonical pt-BR key. Idempotent, and skips a rename that would collide
    /// with an already-present canonical category (leaving the duplicate for the
    /// user to remove) so it never creates a second "Moradia", etc.
    private static func normalizeDefaultCategoryNames(_ context: ModelContext) {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        var presentNames = Set(categories.map(\.name))
        var changed = false
        for category in categories {
            guard let canonical = englishToCanonicalCategory[category.name],
                  canonical != category.name,
                  !presentNames.contains(canonical) else { continue }
            presentNames.remove(category.name)
            presentNames.insert(canonical)
            category.name = canonical
            changed = true
        }
        if changed { try? context.save() }
    }

    private static func seedDefaultCategories(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        // Stored as the canonical (pt-BR) key; the UI localizes it at display
        // time via `Text(LocalizedStringKey:)`, so these follow the app's
        // language switch. The user can still rename or delete them.
        let defaults = ["Moradia", "Alimentação", "Transporte", "Saúde", "Educação", "Lazer", "Mercado", "Contas", "Compras"]
        for name in defaults {
            context.insert(Category(name: name))
        }
    }
}

/// Applies the user-selected UI language by overriding the environment locale,
/// which is what SwiftUI uses to resolve localized `Text`/`Label` strings. Reads
/// the choice from `AppSettings` so it updates live when changed in Settings.
private struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @State private var showingOnboarding = false

    private var language: AppLanguage {
        settings.first?.language ?? .system
    }

    var body: some View {
        let language = self.language
        // Currency presentation follows the same choice as the UI language.
        Money.usesEnglish = language.isEnglishPresentation
        return RootTabView()
            .environment(\.locale, language.resolvedLocale)
            // Gate on the settings singleton: only decide once it exists (it is
            // created synchronously during `bootstrap`, but `onChange` also
            // covers the case where it arrives later via iCloud sync).
            .task { syncOnboarding() }
            .onChange(of: settings) { _, _ in syncOnboarding() }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView { completeOnboarding() }
            }
    }

    private func syncOnboarding() {
        guard let settings = settings.first else { return }
        if !settings.hasCompletedOnboarding {
            showingOnboarding = true
        }
    }

    private func completeOnboarding() {
        settings.first?.hasCompletedOnboarding = true
        try? context.save()
        showingOnboarding = false
    }
}
