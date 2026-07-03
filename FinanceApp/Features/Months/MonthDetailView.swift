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

    // A query here invalidates on every context save, which re-runs this body
    // when entries are added/removed from a presented sheet. Without it,
    // SwiftData's to-many relationship mutations don't reliably re-render this
    // parent view, so the dashboard tiles would stay stale (the hero card
    // refreshes on its own because it holds an @Query too).
    @Query private var allMonths: [Month]

    /// The query-managed instance of the displayed month, so relationship reads
    /// reflect the latest save.
    private var liveMonth: Month {
        allMonths.first { $0.id == month.id } ?? month
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private enum MonthSection: String, Hashable {
        case income, recurring, oneOff, invoice
    }

    private enum ActiveSheet: Identifiable {
        case addIncome
        case addOneOff
        case editIncome(IncomeEntry)
        case editOneOff(OneOffExpense)
        case editRecurring(ExpenseTemplate)

        var id: String {
            switch self {
            case .addIncome: return "addIncome"
            case .addOneOff: return "addOneOff"
            case .editIncome(let entry): return "editIncome-\(entry.id)"
            case .editOneOff(let expense): return "editOneOff-\(expense.id)"
            case .editRecurring(let template): return "editRecurring-\(template.id)"
            }
        }
    }

    private var totals: SummaryMath.Totals { SummaryMath.totals(for: liveMonth) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SummaryHeroCard(month: liveMonth)

                QuickAddBar(
                    onAddIncome: { activeSheet = .addIncome },
                    onAddExpense: { activeSheet = .addOneOff }
                )

                sectionHeader("Lançamentos")

                LazyVGrid(columns: gridColumns, spacing: 10) {
                    DashboardTile(
                        icon: "arrow.down.left",
                        tint: Theme.income,
                        title: "Renda",
                        subtitle: "\(incomeCount) fontes",
                        amount: totals.income + totals.benefit,
                        amountColor: Theme.income
                    ) { pushed = .income }

                    DashboardTile(
                        icon: "arrow.triangle.2.circlepath",
                        tint: Theme.recurring,
                        title: "Despesas recorrentes",
                        subtitle: "\(recurringCount) lançadas",
                        amount: totals.recurring
                    ) { pushed = .recurring }

                    DashboardTile(
                        icon: "cart",
                        tint: Theme.oneOff,
                        title: "Despesas avulsas",
                        subtitle: "\(oneOffCount) lançamentos",
                        amount: totals.oneOff
                    ) { pushed = .oneOff }

                    DashboardTile(
                        icon: "creditcard",
                        tint: Theme.card,
                        title: "Fatura do cartão",
                        subtitle: liveMonth.invoice == nil ? "Não importada" : "Importada",
                        amount: liveMonth.invoice?.totalAmount,
                        placeholder: "Importar"
                    ) { pushed = .invoice }
                }

                CategoryBreakdownCard(month: liveMonth)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
            ToolbarItem(placement: .principal) {
                Button(action: onOpenCalendar) {
                    HStack(spacing: 5) {
                        Text(month.anchorDate.monthNamePtBR)
                            .foregroundStyle(.primary)
                        Text(month.anchorDate.yearLabel)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                }
                .accessibilityLabel(month.anchorDate.monthLabelPtBR)
                .accessibilityHint("Abrir calendário")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    goToAdjacentMonth(next: true)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Próximo mês")
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
                    RecurringSectionView(
                        month: month,
                        onEdit: { activeSheet = .editRecurring($0) }
                    )
                }
            case .oneOff:
                SectionDetailScreen("Despesas avulsas") {
                    OneOffSectionView(
                        month: month,
                        onAdd: { activeSheet = .addOneOff },
                        onEdit: { activeSheet = .editOneOff($0) }
                    )
                }
            case .invoice:
                InvoiceReviewScreen(month: month)
            }
        }
        // Add flows are presented from this root screen — the configuration that
        // reliably presents sheets — never nested inside the detail screen/sheet.
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addIncome:
                AddIncomeSheet(month: month)
            case .addOneOff:
                AddOneOffSheet(month: month)
            case .editIncome(let entry):
                AddIncomeSheet(month: month, editing: entry)
            case .editOneOff(let expense):
                AddOneOffSheet(month: month, editing: expense)
            case .editRecurring(let template):
                SetRecurringAmountSheet(month: month, template: template)
            }
        }
    }

    // MARK: - Counts

    private var incomeCount: Int { liveMonth.incomeEntries?.count ?? 0 }
    private var recurringCount: Int { liveMonth.recurringEntries?.count ?? 0 }
    private var oneOffCount: Int { liveMonth.oneOffs?.count ?? 0 }

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
