import SwiftUI
import SwiftData

/// Top-level view for the Meses tab. Owns the "currently displayed month"
/// state so switching months from the calendar rebinds in place instead of
/// pushing onto the navigation stack.
struct MonthsTabView: View {
    @Environment(\.modelContext) private var context
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
        .task {
            if displayedMonth == nil {
                displayedMonth = MonthRollover.currentMonth(in: context)
            }
        }
        .sheet(isPresented: $showingCalendar) {
            if let displayedMonth {
                MonthCalendarView(currentMonth: displayedMonth) { picked in
                    self.displayedMonth = picked
                    showingCalendar = false
                }
            }
        }
    }
}
