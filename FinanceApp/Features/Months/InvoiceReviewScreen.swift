import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

/// The card-invoice hub for a month: import one or more card statements (Nubank,
/// Itaú or Santander), then review and categorize each purchase. A month can
/// hold several invoices — one per card — shown here as separate sections under
/// a combined per-category breakdown. Categorized transactions fold into the
/// month's overall spending, while this screen stays a place apart to see
/// exactly what was charged on each card.
struct InvoiceReviewScreen: View {
    @Environment(\.modelContext) private var context
    let month: Month

    @Query private var allMonths: [Month]
    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]
    @Query private var rules: [MerchantRule]

    @State private var isImporting = false
    @State private var importError: String?
    @State private var infoMessage: String?
    @State private var categorizing: InvoiceTransaction?
    @State private var editingAmount: InvoiceTransaction?
    @State private var addingTo: CreditCardInvoice?
    @State private var categoryDetail: Category?
    @State private var removingInvoice: CreditCardInvoice?
    /// Bytes of a password-protected PDF, held while we ask for the password
    /// (kept as Data so the retry doesn't depend on the security-scoped URL).
    @State private var lockedData: Data?
    @State private var passwordInput = ""

    /// Query-managed instance so relationship reads reflect the latest save.
    private var liveMonth: Month {
        allMonths.first { $0.id == month.id } ?? month
    }

    /// All card invoices imported into this month, oldest first.
    private var invoices: [CreditCardInvoice] {
        (liveMonth.invoices ?? []).sorted { $0.uploadedAt < $1.uploadedAt }
    }

    /// Every purchase across every card this month — feeds the combined
    /// breakdown and the merchant-rule learning.
    private var allPurchases: [InvoiceTransaction] {
        invoices.flatMap { $0.transactions ?? [] }.filter { !$0.isFee }
    }

    private var categorizedCount: Int { allPurchases.filter { $0.category != nil }.count }
    private var monthTotal: Decimal { invoices.reduce(0) { $0 + $1.totalAmount } }

    /// Every still-uncategorized purchase across all cards, newest first — the
    /// review inbox surfaced at the top so the user can clear them in one place
    /// instead of hunting through each card's section.
    private var uncategorized: [InvoiceTransaction] {
        allPurchases
            .filter { $0.category == nil }
            .sorted { $0.postedDate > $1.postedDate }
    }

    /// Per-category invoice totals across all cards, sorted descending — feeds
    /// the breakdown card.
    private var breakdown: [(category: Category, amount: Decimal)] {
        var buckets: [UUID: (Category, Decimal)] = [:]
        for txn in allPurchases {
            guard let category = txn.category else { continue }
            buckets[category.id, default: (category, 0)].1 += txn.amount
        }
        return buckets.values
            .map { (category: $0.0, amount: $0.1) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        Group {
            if invoices.isEmpty {
                emptyState
            } else {
                populated
            }
        }
        .navigationTitle("Fatura do cartão")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !invoices.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Importar fatura", systemImage: "plus")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(item: $categorizing) { txn in
            InvoiceCategorySheet(transaction: txn) { category in
                assign(category, to: txn)
            }
        }
        .sheet(item: $editingAmount) { txn in
            EditInvoiceAmountSheet(transaction: txn) { newAmount in
                updateAmount(newAmount, for: txn)
            }
        }
        .sheet(item: $categoryDetail) { category in
            InvoiceCategoryDetailSheet(
                category: category,
                transactions: allPurchases
                    .filter { $0.category?.id == category.id }
                    .sorted { $0.postedDate > $1.postedDate }
            )
        }
        .sheet(item: $addingTo) { invoice in
            AddInvoiceTransactionSheet(invoice: invoice)
        }
        .alert(
            "Fatura importada",
            isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })
        ) {
            Button("OK", role: .cancel) { infoMessage = nil }
        } message: {
            Text(infoMessage ?? "")
        }
        .alert(
            "Remover fatura?",
            isPresented: Binding(get: { removingInvoice != nil }, set: { if !$0 { removingInvoice = nil } })
        ) {
            Button("Cancelar", role: .cancel) { removingInvoice = nil }
            Button("Remover", role: .destructive, action: confirmRemoveInvoice)
        } message: {
            Text("As compras importadas e suas categorias serão apagadas deste mês.")
        }
        .alert(
            "Não foi possível importar",
            isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
        ) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert(
            "Fatura protegida",
            isPresented: Binding(get: { lockedData != nil }, set: { if !$0 { dismissPasswordPrompt() } })
        ) {
            SecureField("Senha", text: $passwordInput)
            Button("Cancelar", role: .cancel) { dismissPasswordPrompt() }
            Button("Abrir") { unlockAndImport() }
        } message: {
            Text("Este PDF pede senha (bancos costumam usar dígitos do CPF do titular).")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.card)
                    .padding(.top, 48)

                Text("Importe a fatura do cartão")
                    .font(.title3.weight(.semibold))

                Text("Selecione o PDF da fatura do Nubank, Itaú ou Santander. Cada compra aparece aqui para você categorizar — e entra no total de gastos do mês. Você pode importar mais de um cartão.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    isImporting = true
                } label: {
                    Label("Importar PDF", systemImage: "doc.badge.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                .fill(Theme.card)
                        )
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Populated

    private var populated: some View {
        List {
            if !breakdown.isEmpty {
                Section {
                    InvoiceBreakdownCard(rows: breakdown) { category in
                        categoryDetail = category
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            summarySection

            if !uncategorized.isEmpty {
                uncategorizedSection
            }

            ForEach(invoices) { invoice in
                invoiceSection(invoice)
            }
        }
    }

    /// Cross-card review inbox: only the uncategorized purchases, so the user can
    /// see and clear them at a glance. Rows drop out as they're categorized;
    /// the whole section disappears once nothing is left to review.
    private var uncategorizedSection: some View {
        Section {
            ForEach(uncategorized) { txn in
                row(txn, showsCard: invoices.count > 1)
            }
        } header: {
            HStack(spacing: 6) {
                Label("A revisar", systemImage: "questionmark.circle.fill")
                    .foregroundStyle(Theme.oneOff)
                Spacer()
                Text("\(uncategorized.count)")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.semibold))
            .textCase(nil)
        } footer: {
            Text("Compras sem categoria não entram nas categorias do mês. Toque para categorizar.")
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent(invoices.count > 1 ? "Total das faturas" : "Total da fatura") {
                Text(monthTotal.brl)
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            if !allPurchases.isEmpty {
                LabeledContent("Categorizadas") {
                    Text("\(categorizedCount) de \(allPurchases.count)")
                        .foregroundStyle(categorizedCount == allPurchases.count ? Theme.income : .secondary)
                }
            }
        }
    }

    private func invoiceSection(_ invoice: CreditCardInvoice) -> some View {
        let purchases = (invoice.transactions ?? [])
            .filter { !$0.isFee }
            .sorted { $0.postedDate > $1.postedDate }
        let toReview = purchases.filter { $0.category == nil }.count

        return Section {
            ForEach(purchases) { txn in
                row(txn)
            }
            Button {
                addingTo = invoice
            } label: {
                Label("Adicionar lançamento", systemImage: "plus.circle")
            }
        } header: {
            HStack(spacing: 6) {
                Text(invoice.bankName.isEmpty ? "Fatura" : invoice.bankName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if toReview > 0 {
                    Text("· \(toReview) a revisar")
                        .foregroundStyle(Theme.oneOff)
                }
                Spacer()
                Text(invoice.totalAmount.brl)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Menu {
                    Button(role: .destructive) {
                        removingInvoice = invoice
                    } label: {
                        Label("Remover fatura", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Opções da fatura")
            }
            .font(.footnote)
            .textCase(nil)
        }
    }

    private func row(_ txn: InvoiceTransaction, showsCard: Bool = false) -> some View {
        Button {
            categorizing = txn
        } label: {
            InvoiceTransactionRow(
                transaction: txn,
                cardName: showsCard ? txn.invoice?.bankName : nil
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteTransaction(txn)
            } label: {
                Label("Excluir", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                editingAmount = txn
            } label: {
                Label("Valor", systemImage: "pencil")
            }
            .tint(Theme.card)
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            importPDF(from: url)
        }
    }

    private func importPDF(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            importError = "Não consegui abrir o PDF."
            return
        }
        importPDF(data: data)
    }

    private func importPDF(data: Data, password: String? = nil) {
        guard let document = PDFDocument(data: data) else {
            importError = "Não consegui abrir o PDF."
            return
        }

        // Password-protected PDFs (Itaú) must be unlocked before reading text.
        if document.isLocked {
            if let password, document.unlock(withPassword: password) {
                // unlocked — fall through
            } else {
                lockedData = data // ask (or re-ask) for the password
                return
            }
        }

        guard let text = document.string else {
            importError = "Não consegui ler o texto do PDF."
            return
        }

        // Parsing is layered, each pass a fallback for the previous one — every
        // pass only runs when the prior one found nothing, so well-behaved
        // statements are unaffected:
        //   1. the PDF's linear text (correct for single-column statements);
        //   2. a geometry-reconstructed reading order (fixes multi-column
        //      layouts that `PDFDocument.string` scrambles);
        //   3. an Itaú row/cell table extractor (for the "eStatements" layout
        //      whose font also injects spaces inside dates and amounts).
        var result = InvoiceParsing.parse(text: text, periodEnd: month.anchorDate)
        if result?.invoice.transactions.isEmpty ?? true {
            let reconstructed = PDFGeometryText.reconstruct(document: document)
            if let retry = InvoiceParsing.parse(text: reconstructed, periodEnd: month.anchorDate),
               !retry.invoice.transactions.isEmpty {
                result = retry
            }
        }
        if result?.invoice.transactions.isEmpty ?? true {
            if let table = ItauGeometryTable.parse(document: document, periodEnd: month.anchorDate) {
                result = (bank: .itau, invoice: table)
            }
        }

        // Last resort: some Itaú "eStatements" layouts (two-column, multi-page,
        // occasionally international) can't be itemized reliably. Import a
        // total-only invoice — the statement total reads cleanly — so the
        // month's card spending stays correct; the user adds the individual
        // charges by hand from the review screen.
        var totalOnly = false
        if result?.invoice.transactions.isEmpty ?? true,
           InvoiceParsing.detectBank(in: text) == .itau,
           let total = ItauGeometryTable.statedTotal(document: document), total > 0 {
            result = (bank: .itau, invoice: ParsedInvoice(transactions: [], total: total))
            totalOnly = true
        }

        guard let (bank, parsed) = result else {
            importError = "Não reconheci o banco desta fatura. Por ora suportamos Nubank, Itaú e Santander."
            return
        }
        guard totalOnly || !parsed.transactions.isEmpty else {
            importError = "Nenhuma transação encontrada. Verifique se é o PDF da fatura do \(bank.displayName)."
            return
        }

        // Adds a new invoice alongside any already imported, so a second card
        // can live in the same month.
        let invoice = CreditCardInvoice(
            month: liveMonth,
            uploadedAt: Date(),
            totalAmount: parsed.total,
            bankName: bank.displayName
        )
        context.insert(invoice)

        for item in parsed.transactions {
            let suggested = item.isFee
                ? nil
                : MerchantCategorizer.category(
                    forKey: item.merchantKey,
                    rules: rules,
                    categories: categories,
                    suggestedName: item.suggestedCategoryName
                )
            context.insert(
                InvoiceTransaction(
                    invoice: invoice,
                    postedDate: item.date,
                    rawDescription: item.rawDescription,
                    merchantKey: item.merchantKey,
                    amount: item.amount,
                    category: suggested,
                    installmentCurrent: item.installmentCurrent,
                    installmentTotal: item.installmentTotal,
                    isFee: item.isFee
                )
            )
        }
        try? context.save()

        if totalOnly {
            infoMessage = "Importamos o total desta fatura (\(parsed.total.brl)). Este formato do Itaú não permite ler os lançamentos automaticamente — use \"Adicionar lançamento\" para incluí-los e categorizá-los."
        }
    }

    private func unlockAndImport() {
        guard let data = lockedData else { return }
        let password = passwordInput
        lockedData = nil
        passwordInput = ""
        importPDF(data: data, password: password)
    }

    private func dismissPasswordPrompt() {
        lockedData = nil
        passwordInput = ""
    }

    private func confirmRemoveInvoice() {
        guard let invoice = removingInvoice else { return }
        removingInvoice = nil
        context.delete(invoice)
        try? context.save()
    }

    // MARK: - Line editing

    // `totalAmount` stays the statement's authoritative total — it is not
    // recomputed from the lines. The itemization can be partial (a manually
    // entered invoice, or one where a mis-parsed line was removed) without
    // throwing off the month's card-spending total.

    private func deleteTransaction(_ txn: InvoiceTransaction) {
        context.delete(txn)
        try? context.save()
    }

    private func updateAmount(_ amount: Decimal, for txn: InvoiceTransaction) {
        txn.amount = amount
        try? context.save()
    }

    // MARK: - Categorization

    /// Assigns a category and learns it: every transaction in the month from the
    /// same merchant gets the category, and a `MerchantRule` is upserted so
    /// future statements categorize it automatically.
    private func assign(_ category: Category, to txn: InvoiceTransaction) {
        let key = txn.merchantKey
        for other in allPurchases where other.merchantKey == key {
            other.category = category
        }
        upsertRule(merchantKey: key, category: category)
        try? context.save()
    }

    private func upsertRule(merchantKey: String, category: Category) {
        let trimmed = merchantKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let rule = rules.first(where: { $0.merchantKey.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            rule.category = category
            rule.lastUsedAt = Date()
        } else {
            context.insert(MerchantRule(merchantKey: trimmed, category: category, lastUsedAt: Date()))
        }
    }
}
