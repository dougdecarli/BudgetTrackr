import Foundation

enum SummaryMath {
    struct Totals {
        var income: Decimal = 0
        var benefit: Decimal = 0
        var tax: Decimal = 0
        var recurring: Decimal = 0
        var oneOff: Decimal = 0
        var invoice: Decimal = 0
        var ticketCardSpend: Decimal = 0

        var spending: Decimal { recurring + oneOff + invoice }
        var netResult: Decimal { (income + benefit) - tax - spending }
        // Em-dinheiro variants exclude the benefit-funded ticket-card portion
        // from each side. Diverges from data-model spec's single netResultEmDin formula.
        var incomeEmDinheiro: Decimal { income }
        var spendingEmDinheiro: Decimal { spending - ticketCardSpend }
        var netResultEmDinheiro: Decimal { incomeEmDinheiro - spendingEmDinheiro }
    }

    static func totals(for month: Month) -> Totals {
        var t = Totals()

        for entry in month.incomeEntries ?? [] {
            switch entry.source?.type {
            // "Bônus" and "Outros" (13º salário, FGTS, etc.) are money earned,
            // so they count as income — folding them here makes every
            // "income + benefit" total pick them up automatically.
            case .income, .bonus, .other: t.income += entry.amount
            case .benefit:                t.benefit += entry.amount
            case .tax:                    t.tax += entry.amount
            case .none:                   break
            }
        }

        for entry in month.recurringEntries ?? [] {
            t.recurring += entry.amount
            if entry.template?.isTicketCard == true {
                t.ticketCardSpend += entry.amount
            }
        }

        for entry in month.oneOffs ?? [] {
            t.oneOff += entry.amount
        }

        for invoice in month.invoices ?? [] {
            t.invoice += invoice.totalAmount
        }
        return t
    }

    /// Category breakdown for a month, combining one-offs, recurring (under template's
    /// category), and invoice category totals. Sorted descending by amount.
    static func categoryBreakdown(for month: Month) -> [(category: Category, amount: Decimal)] {
        var buckets: [UUID: (Category, Decimal)] = [:]

        for entry in month.recurringEntries ?? [] {
            guard let cat = entry.template?.category else { continue }
            buckets[cat.id, default: (cat, 0)].1 += entry.amount
        }
        for entry in month.oneOffs ?? [] {
            guard let cat = entry.category else { continue }
            buckets[cat.id, default: (cat, 0)].1 += entry.amount
        }
        // Invoice spending folds in per categorized transaction, across every
        // card imported this month. Fee lines (IOF) carry no category and are
        // skipped.
        for invoice in month.invoices ?? [] {
            for txn in invoice.transactions ?? [] {
                guard let cat = txn.category, !txn.isFee else { continue }
                buckets[cat.id, default: (cat, 0)].1 += txn.amount
            }
        }

        return buckets.values
            .map { ($0.0, $0.1) }
            .sorted { $0.1 > $1.1 }
    }

    /// One categorized expense line, source-tagged so the detail view can badge
    /// where it came from.
    struct ExpenseLine: Identifiable {
        enum Source { case recurring, oneOff, invoice }
        let id: UUID
        let label: String
        let amount: Decimal
        let source: Source
    }

    /// A category with its month total and the individual lines behind it.
    struct ExpenseGroup: Identifiable {
        let category: Category
        let amount: Decimal
        let lines: [ExpenseLine]
        var id: UUID { category.id }
    }

    /// Every categorized expense for a month grouped by category — the drill-down
    /// behind the "Para onde foi" donut. Mirrors `categoryBreakdown` (same
    /// sources, same "skip uncategorized/fees" rules) but keeps the individual
    /// lines. Groups are sorted by total, and lines within each by amount, both
    /// descending.
    static func categorizedExpenseGroups(for month: Month) -> [ExpenseGroup] {
        var buckets: [UUID: (category: Category, lines: [ExpenseLine])] = [:]

        func add(_ line: ExpenseLine, to category: Category) {
            buckets[category.id, default: (category, [])].lines.append(line)
        }

        for entry in month.recurringEntries ?? [] {
            guard let cat = entry.template?.category else { continue }
            add(ExpenseLine(id: entry.id, label: entry.template?.label ?? "", amount: entry.amount, source: .recurring), to: cat)
        }
        for entry in month.oneOffs ?? [] {
            guard let cat = entry.category else { continue }
            add(ExpenseLine(id: entry.id, label: entry.label, amount: entry.amount, source: .oneOff), to: cat)
        }
        for invoice in month.invoices ?? [] {
            for txn in invoice.transactions ?? [] {
                guard let cat = txn.category, !txn.isFee else { continue }
                add(ExpenseLine(id: txn.id, label: txn.rawDescription, amount: txn.amount, source: .invoice), to: cat)
            }
        }

        return buckets.values
            .map { bucket in
                let lines = bucket.lines.sorted { $0.amount > $1.amount }
                let total = lines.reduce(Decimal(0)) { $0 + $1.amount }
                return ExpenseGroup(category: bucket.category, amount: total, lines: lines)
            }
            .sorted { $0.amount > $1.amount }
    }

    /// `nil` when previous total is zero (delta undefined).
    static func percentDelta(current: Decimal, previous: Decimal) -> Double? {
        guard previous != 0 else { return nil }
        let delta = (current - previous) / abs(previous)
        return NSDecimalNumber(decimal: delta).doubleValue
    }
}
