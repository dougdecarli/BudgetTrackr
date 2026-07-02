import SwiftUI
import SwiftData

struct MonthDetailView: View {
    @Environment(\.modelContext) private var context
    let month: Month
    let onOpenCalendar: () -> Void
    /// Rebinds the displayed month in the parent (owned by `MonthsTabView`).
    let onSelectMonth: (Month) -> Void

    @State private var pushed: MonthSection?
    @State private var activeSheet: ActiveSheet?
    @State private var promptForTemplate: OneOffExpense?

    private enum MonthSection: String, Hashable {
        case income, recurring, oneOff, invoice
    }

    private enum ActiveSheet: Identifiable {
        case addIncome
        case addOneOff
        case editIncome(IncomeEntry)

        var id: String {
            switch self {
            case .addIncome: return "addIncome"
            case .addOneOff: return "addOneOff"
            case .editIncome(let entry): return "editIncome-\(entry.id)"
            }
        }
    }

    private var totals: SummaryMath.Totals { SummaryMath.totals(for: month) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SummaryHeroCard(month: month)

                sectionHeader("Lançamentos")

                VStack(spacing: 12) {
                    DashboardCard(
                        icon: "arrow.down.left",
                        tint: .green,
                        title: "Renda",
                        subtitle: "\(incomeCount) fontes",
                        amount: totals.income + totals.benefit,
                        amountColor: .green
                    ) { pushed = .income }

                    DashboardCard(
                        icon: "arrow.triangle.2.circlepath",
                        tint: .indigo,
                        title: "Despesas recorrentes",
                        subtitle: "\(recurringCount) lançadas",
                        amount: totals.recurring
                    ) { pushed = .recurring }

                    DashboardCard(
                        icon: "cart",
                        tint: .orange,
                        title: "Despesas avulsas",
                        subtitle: "\(oneOffCount) lançamentos",
                        amount: totals.oneOff
                    ) { pushed = .oneOff }

                    DashboardCard(
                        icon: "creditcard",
                        tint: .blue,
                        title: "Fatura do cartão",
                        subtitle: month.invoice == nil ? "Não importada" : "Importada",
                        amount: month.invoice?.totalAmount,
                        placeholder: "Importar"
                    ) { pushed = .invoice }
                }

                CategoryBreakdownCard(month: month)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(month.anchorDate.monthLabelPtBR)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    goToAdjacentMonth(next: false)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Mês anterior")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    goToAdjacentMonth(next: true)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Próximo mês")

                Button(action: onOpenCalendar) {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Calendário")
            }
        }
        // Detail is a navigation push (stable, top-most screen).
        .navigationDestination(item: $pushed) { section in
            switch section {
            case .income:
                SectionDetailScreen("Renda") {
                    IncomeSectionView(
                        month: month,
                        onAdd: { activeSheet = .addIncome },
                        onEdit: { activeSheet = .editIncome($0) }
                    )
                }
            case .recurring:
                SectionDetailScreen("Despesas recorrentes") {
                    RecurringSectionView(month: month)
                }
            case .oneOff:
                SectionDetailScreen("Despesas avulsas") {
                    OneOffSectionView(month: month) { activeSheet = .addOneOff }
                }
            case .invoice:
                SectionDetailScreen("Fatura do cartão") {
                    InvoiceSectionView(month: month)
                }
            }
        }
        // Add flows are presented from this root screen — the configuration that
        // reliably presents sheets — never nested inside the detail screen/sheet.
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addIncome:
                AddIncomeSheet(month: month)
            case .addOneOff:
                AddOneOffSheet(month: month) { saved in promptForTemplate = saved }
            case .editIncome(let entry):
                AddIncomeSheet(month: month, editing: entry)
            }
        }
        .confirmationDialog(
            "Salvar como despesa recorrente?",
            isPresented: Binding(
                get: { promptForTemplate != nil },
                set: { if !$0 { promptForTemplate = nil } }
            ),
            presenting: promptForTemplate
        ) { entry in
            Button("Salvar como recorrente") {
                createTemplate(from: entry)
                promptForTemplate = nil
            }
            Button("Não, obrigado", role: .cancel) {
                promptForTemplate = nil
            }
        } message: { entry in
            Text("\u{201C}\(entry.label)\u{201D} passa a aparecer todo mês a partir do próximo.")
        }
    }

    private func createTemplate(from oneOff: OneOffExpense) {
        let template = ExpenseTemplate(
            label: oneOff.label,
            category: oneOff.category,
            isTicketCard: false
        )
        context.insert(template)
        try? context.save()
    }

    // MARK: - Counts

    private var incomeCount: Int { month.incomeEntries?.count ?? 0 }
    private var recurringCount: Int { month.recurringEntries?.count ?? 0 }
    private var oneOffCount: Int { month.oneOffs?.count ?? 0 }

    // MARK: - Navigation

    private func goToAdjacentMonth(next: Bool) {
        let anchor = next ? month.anchorDate.nextMonthAnchor : month.anchorDate.previousMonthAnchor
        let target = MonthRollover.resolve(anchor: anchor, in: context)
        onSelectMonth(target)
    }

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}
