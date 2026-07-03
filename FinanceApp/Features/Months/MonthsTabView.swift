import SwiftUI
import SwiftData

/// Top-level view for the Meses tab. Owns the "currently displayed month"
/// state so switching months from the calendar rebinds in place instead of
/// pushing onto the navigation stack.
struct MonthsTabView: View {
    @Environment(\.modelContext) private var context
    // Observed only so the view reacts to iCloud sync: when records arrive (or
    // duplicates are merged), these change and `reconcile()` re-runs.
    @Query(sort: [SortDescriptor(\Month.anchorDate)]) private var months: [Month]
    @Query(sort: [SortDescriptor(\Category.name)]) private var categories: [Category]

    @State private var displayedMonth: Month?
    @State private var showingCalendar = false

    var body: some View {
        Group {
            if let month = displayedMonth {
                MonthDetailView(month: month) {
                    showingCalendar = true
                } onSelectMonth: { picked in
                    displayedMonth = picked
                }
            } else {
                ProgressView()
                    .navigationTitle("Meses")
            }
        }
        .task { reconcile() }
        .onChange(of: months) { _, _ in reconcile() }
        .onChange(of: categories) { _, _ in reconcile() }
        .sheet(isPresented: $showingCalendar) {
            if let displayedMonth {
                MonthCalendarView(currentMonth: displayedMonth) { picked in
                    self.displayedMonth = picked
                    showingCalendar = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    /// Merges any duplicate records synced in from iCloud, then makes sure the
    /// displayed month still points at the surviving (canonical) record for the
    /// same anchor — so the dashboard shows the month that actually holds the
    /// entries instead of a locally-created empty duplicate.
    private func reconcile() {
        let anchor = displayedMonth?.anchorDate
        let previousID = displayedMonth?.id

        DataDeduplication.run(in: context)

        if let anchor {
            let canonical = MonthRollover.resolve(anchor: anchor, in: context)
            if previousID != canonical.id {
                displayedMonth = canonical
            }
        } else {
            displayedMonth = MonthRollover.currentMonth(in: context)
        }
    }
}
