import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

/// The card-invoice hub for a month: import a Nubank or Itaú PDF (unlocking it
/// first if it's password-protected), then review and categorize each purchase.
/// Categorized transactions fold into the month's overall spending breakdown,
/// while this screen stays a place apart to see exactly what was charged on the
/// card.
struct InvoiceReviewScreen: View {
    @Environment(\.modelContext) private var context
    let month: Month

    @Query private var allMonths: [Month]
    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]
    @Query private var rules: [MerchantRule]

    @State private var isImporting = false
    @State private var importError: String?
    @State private var categorizing: InvoiceTransaction?
    @State private var confirmingRemoval = false
    /// Bytes of a password-protected PDF, held while we ask for the password
    /// (kept as Data so the retry doesn't depend on the security-scoped URL).
    @State private var lockedData: Data?
    @State private var passwordInput = ""

    /// Query-managed instance so relationship reads reflect the latest save.
    private var liveMonth: Month {
        allMonths.first { $0.id == month.id } ?? month
    }

    private var invoice: CreditCardInvoice? { liveMonth.invoice }

    private var transactions: [InvoiceTransaction] {
        (invoice?.transactions ?? []).sorted { $0.postedDate > $1.postedDate }
    }

    private var purchases: [InvoiceTransaction] { transactions.filter { !$0.isFee } }
    private var toReview: [InvoiceTransaction] { purchases.filter { $0.category == nil } }
    private var categorized: [InvoiceTransaction] { purchases.filter { $0.category != nil } }

    /// Per-category invoice totals, sorted descending — feeds the breakdown card.
    private var breakdown: [(category: Category, amount: Decimal)] {
        var buckets: [UUID: (Category, Decimal)] = [:]
        for txn in categorized {
            guard let category = txn.category else { continue }
            buckets[category.id, default: (category, 0)].1 += txn.amount
        }
        return buckets.values
            .map { (category: $0.0, amount: $0.1) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        Group {
            if invoice == nil {
                emptyState
            } else {
                populated
            }
        }
        .navigationTitle("Fatura do cartão")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if invoice != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isImporting = true
                        } label: {
                            Label("Reimportar PDF", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            confirmingRemoval = true
                        } label: {
                            Label("Remover fatura", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
        .alert("Remover fatura?", isPresented: $confirmingRemoval) {
            Button("Cancelar", role: .cancel) {}
            Button("Remover", role: .destructive, action: removeInvoice)
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

                Text("Selecione o PDF da fatura do Nubank, Itaú ou Santander. Cada compra aparece aqui para você categorizar — e entra no total de gastos do mês.")
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
                    InvoiceBreakdownCard(rows: breakdown)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            summarySection

            if !toReview.isEmpty {
                Section {
                    ForEach(toReview) { txn in
                        row(txn)
                    }
                } header: {
                    Text("A revisar · \(toReview.count)")
                }
            }

            if !categorized.isEmpty {
                Section {
                    ForEach(categorized) { txn in
                        row(txn)
                    }
                } header: {
                    Text("Categorizadas · \(categorized.count)")
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Total da fatura") {
                Text((invoice?.totalAmount ?? 0).brl)
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            if !purchases.isEmpty {
                LabeledContent("Categorizadas") {
                    Text("\(categorized.count) de \(purchases.count)")
                        .foregroundStyle(toReview.isEmpty ? Theme.income : .secondary)
                }
            }
            if let uploadedAt = invoice?.uploadedAt {
                Text("Importada em \(uploadedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ txn: InvoiceTransaction) -> some View {
        Button {
            categorizing = txn
        } label: {
            InvoiceTransactionRow(transaction: txn)
        }
        .buttonStyle(.plain)
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

        guard let (bank, parsed) = InvoiceParsing.parse(text: text, periodEnd: month.anchorDate) else {
            importError = "Não reconheci o banco desta fatura. Por ora suportamos Nubank e Itaú."
            return
        }
        guard !parsed.transactions.isEmpty else {
            importError = "Nenhuma transação encontrada. Verifique se é o PDF da fatura do \(bank.displayName)."
            return
        }

        // A fresh import replaces any prior invoice for this month.
        if let existing = liveMonth.invoice {
            context.delete(existing)
        }

        let invoice = CreditCardInvoice(
            month: liveMonth,
            uploadedAt: Date(),
            totalAmount: parsed.total
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

    private func removeInvoice() {
        if let invoice = liveMonth.invoice {
            context.delete(invoice)
            try? context.save()
        }
    }

    // MARK: - Categorization

    /// Assigns a category and learns it: every transaction in this invoice from
    /// the same merchant gets the category, and a `MerchantRule` is upserted so
    /// future statements categorize it automatically.
    private func assign(_ category: Category, to txn: InvoiceTransaction) {
        let key = txn.merchantKey
        for other in transactions where other.merchantKey == key && !other.isFee {
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
