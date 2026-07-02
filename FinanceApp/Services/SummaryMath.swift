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
            // "Outros" (13º salário, FGTS, etc.) is money earned, so it counts
            // as income — folding it here makes every "income + benefit" total
            // pick it up automatically.
            case .income, .other: t.income += entry.amount
            case .benefit:        t.benefit += entry.amount
            case .tax:            t.tax += entry.amount
            case .none:           break
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

        t.invoice = month.invoice?.totalAmount ?? 0
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
        for total in month.invoice?.categoryTotals ?? [] {
            guard let cat = total.category else { continue }
            buckets[cat.id, default: (cat, 0)].1 += total.amount
        }

        return buckets.values
            .map { ($0.0, $0.1) }
            .sorted { $0.1 > $1.1 }
    }

    /// `nil` when previous total is zero (delta undefined).
    static func percentDelta(current: Decimal, previous: Decimal) -> Double? {
        guard previous != 0 else { return nil }
        let delta = (current - previous) / abs(previous)
        return NSDecimalNumber(decimal: delta).doubleValue
    }
}
