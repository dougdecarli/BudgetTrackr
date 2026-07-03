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

    private var todayYM: (year: Int, month: Int) {
        (calendar.component(.year, from: Date()),
         calendar.component(.month, from: Date()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(yearsToShow, id: \.self) { year in
                        yearSection(year)
                    }
                    legend
                        .padding(.top, 4)
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

    private var legend: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                Text("Com lançamentos")
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                Text("Mês atual")
            }
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func yearSection(_ year: Int) -> some View {
        let withData = monthsWithData(in: year)
        VStack(alignment: .leading, spacing: 12) {
            Text(String(year))
                .font(.title3.weight(.bold))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(0..<12, id: \.self) { idx in
                    let monthNum = idx + 1
                    monthCell(
                        year: year,
                        month: monthNum,
                        label: monthAbbrevs[idx],
                        isSelected: currentYM == (year, monthNum),
                        isCurrent: todayYM == (year, monthNum),
                        hasData: withData.contains(monthNum)
                    )
                }
            }
        }
    }

    private func monthCell(
        year: Int,
        month: Int,
        label: String,
        isSelected: Bool,
        isCurrent: Bool,
        hasData: Bool
    ) -> some View {
        let foreground: Color = isSelected ? .white : (isCurrent ? .accentColor : .primary)
        return Button {
            pick(year: year, month: month)
        } label: {
            Text(label)
                .font(.callout)
                .fontWeight(isSelected || isCurrent ? .semibold : .regular)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isCurrent && !isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
                .overlay(alignment: .topTrailing) {
                    if hasData {
                        Circle()
                            .fill(isSelected ? Color.white : Color.accentColor)
                            .frame(width: 6, height: 6)
                            .padding(7)
                    }
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
