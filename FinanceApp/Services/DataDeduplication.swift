import Foundation
import SwiftData

/// Reconciles duplicate records that can appear right after a fresh install
/// syncs from CloudKit.
///
/// The app creates some records locally at launch — the current `Month`, the
/// seeded `Category` set, the `AppSettings` singleton — before iCloud finishes
/// downloading the user's existing ones. That race leaves two records for the
/// same real-world thing. We merge them by a natural key, keeping the
/// earliest-created record (the original that synced down) and moving any
/// children onto it, so the rest of the app sees a single canonical record.
enum DataDeduplication {
    static func run(in context: ModelContext) {
        deduplicateMonths(in: context)
        deduplicateCategories(in: context)
        deduplicateSettings(in: context)
    }

    // MARK: - Months (keyed by month anchor)

    static func deduplicateMonths(in context: ModelContext) {
        let all = (try? context.fetch(
            FetchDescriptor<Month>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []

        var canonical: [Date: Month] = [:]
        var changed = false
        for month in all {
            if let keep = canonical[month.anchorDate] {
                merge(month, into: keep, in: context)
                changed = true
            } else {
                canonical[month.anchorDate] = month
            }
        }
        if changed { try? context.save() }
    }

    /// Moves `dup`'s children onto `keep`, then deletes `dup`. Reassigning first
    /// matters: `Month`'s relationships cascade-delete, so an entry still owned
    /// by `dup` when it's deleted would be lost.
    private static func merge(_ dup: Month, into keep: Month, in context: ModelContext) {
        for entry in dup.incomeEntries ?? [] { entry.month = keep }
        for entry in dup.recurringEntries ?? [] { entry.month = keep }
        for expense in dup.oneOffs ?? [] { expense.month = keep }

        if keep.invoice == nil {
            dup.invoice?.month = keep
        } else if let invoice = dup.invoice {
            context.delete(invoice)
        }

        let existing = Set((keep.skippedTemplates ?? []).map(\.id))
        let added = (dup.skippedTemplates ?? []).filter { !existing.contains($0.id) }
        if !added.isEmpty {
            keep.skippedTemplates = (keep.skippedTemplates ?? []) + added
        }

        context.delete(dup)
    }

    // MARK: - Categories (keyed by lowercased name)

    static func deduplicateCategories(in context: ModelContext) {
        let all = (try? context.fetch(
            FetchDescriptor<Category>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []

        var canonical: [String: Category] = [:]
        var changed = false
        for category in all {
            let key = category.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            if let keep = canonical[key] {
                merge(category, into: keep)
                context.delete(category)
                changed = true
            } else {
                canonical[key] = category
            }
        }
        if changed { try? context.save() }
    }

    /// `Category`'s relationships nullify on delete, so reassigning first keeps
    /// the templates / expenses / totals / rules pointing at the survivor.
    private static func merge(_ dup: Category, into keep: Category) {
        for template in dup.templates ?? [] { template.category = keep }
        for oneOff in dup.oneOffs ?? [] { oneOff.category = keep }
        for total in dup.invoiceTotals ?? [] { total.category = keep }
        for rule in dup.merchantRules ?? [] { rule.category = keep }
    }

    // MARK: - AppSettings (singleton)

    static func deduplicateSettings(in context: ModelContext) {
        let all = (try? context.fetch(
            FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.id)])
        )) ?? []
        guard all.count > 1 else { return }
        for extra in all.dropFirst() { context.delete(extra) }
        try? context.save()
    }
}
