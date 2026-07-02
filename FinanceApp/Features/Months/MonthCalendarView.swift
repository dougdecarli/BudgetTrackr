import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let currentMonth: Month
    let onPick: (Month) -> Void

    @Query(sort: [SortDescriptor(\Month.anchorDate)]) private var months: [Month]

    private let calendar = Calendar.current
    private let monthAbbrevs = [
        "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
        "Jul", "Ago", "Set", "Out", "Nov", "Dez",
    ]

    private var yearsToShow: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        let earliestYear = months.first.map { calendar.component(.year, from: $0.anchorDate) } ?? currentYear
        return Array(earliestYear...currentYear).reversed()
    }

    private func monthsWithData(in year: Int) -> Set<Int> {
        var result: Set<Int> = []
        for m in months where calendar.component(.year, from: m.anchorDate) == year {
            if hasRecordedData(m) {
                result.insert(calendar.component(.month, from: m.anchorDate))
            }
        }
        return result
    }

    private func hasRecordedData(_ m: Month) -> Bool {
        !(m.incomeEntries?.isEmpty ?? true)
            || !(m.recurringEntries?.isEmpty ?? true)
            || !(m.oneOffs?.isEmpty ?? true)
            || m.invoice != nil
    }

    private var currentYM: (year: Int, month: Int) {
        (calendar.component(.year, from: currentMonth.anchorDate),
         calendar.component(.month, from: currentMonth.anchorDate))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(yearsToShow, id: \.self) { year in
                        yearSection(year)
                    }
                }
                .padding()
            }
            .navigationTitle("Calendário")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func yearSection(_ year: Int) -> some View {
        let withData = monthsWithData(in: year)
        VStack(alignment: .leading, spacing: 12) {
            Text(String(year))
                .font(.title3.weight(.semibold))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 16
            ) {
                ForEach(0..<12, id: \.self) { idx in
                    let monthNum = idx + 1
                    monthCell(
                        year: year,
                        month: monthNum,
                        label: monthAbbrevs[idx],
                        isSelected: currentYM == (year, monthNum),
                        hasData: withData.contains(monthNum)
                    )
                }
            }
        }
    }

    private func monthCell(year: Int, month: Int, label: String, isSelected: Bool, hasData: Bool) -> some View {
        Button {
            pick(year: year, month: month)
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
                    )
                Circle()
                    .fill(hasData ? Color.accentColor : Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func pick(year: Int, month: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let anchor = calendar.date(from: comps) else { return }
        let picked = MonthRollover.resolve(anchor: anchor, in: context)
        onPick(picked)
    }
}
