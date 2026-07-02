import Foundation
import SwiftData

enum MonthRollover {
    /// Returns the `Month` for the given anchor date, creating it if it doesn't exist.
    @discardableResult
    static func resolve(anchor: Date, in context: ModelContext) -> Month {
        let normalized = anchor.monthAnchor
        let descriptor = FetchDescriptor<Month>(
            predicate: #Predicate { $0.anchorDate == normalized }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let new = Month(anchorDate: normalized)
        context.insert(new)
        try? context.save()
        return new
    }

    /// Resolves the `Month` for the current calendar month (auto-rolls on the 1st).
    @discardableResult
    static func currentMonth(in context: ModelContext) -> Month {
        resolve(anchor: Date.currentMonthAnchor - 1, in: context)
    }

    /// Returns the most recent existing month strictly before the given anchor, if any.
    /// Does not create historical months.
    static func previous(of month: Month, in context: ModelContext) -> Month? {
        let anchor = month.anchorDate
        var descriptor = FetchDescriptor<Month>(
            predicate: #Predicate { $0.anchorDate < anchor },
            sortBy: [SortDescriptor(\.anchorDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Returns the earliest existing month strictly after the given anchor, if any.
    /// Does not create future months.
    static func next(of month: Month, in context: ModelContext) -> Month? {
        let anchor = month.anchorDate
        var descriptor = FetchDescriptor<Month>(
            predicate: #Predicate { $0.anchorDate > anchor },
            sortBy: [SortDescriptor(\.anchorDate)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// All months, newest first. For the drawer / history view.
    static func allMonths(in context: ModelContext) -> [Month] {
        let descriptor = FetchDescriptor<Month>(
            sortBy: [SortDescriptor(\.anchorDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
