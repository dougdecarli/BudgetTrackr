import SwiftUI
import Charts

/// One slice of the spending donut: a category, its amount, and the color it
/// shares with its chip elsewhere.
struct SpendingSlice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let amount: Decimal
    let color: Color

    var value: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

enum SpendingDonut {
    /// Builds slices from a category breakdown. Every category gets its own
    /// slice — the ring shows the full picture; the legend is what folds.
    static func slices(from breakdown: [(category: Category, amount: Decimal)]) -> [SpendingSlice] {
        breakdown.map { item in
            // Store the raw name/key; the legend localizes it at display time.
            SpendingSlice(
                id: item.category.id,
                name: item.category.name.isEmpty ? "Sem categoria" : item.category.name,
                amount: item.amount,
                color: Theme.tint(for: item.category.id)
            )
        }
    }
}

/// Donut chart + legend showing how spending splits across categories. The
/// ring plots every category; tapping a slice (or its legend row) pops it out
/// and swaps the center total for that category's name, value and share —
/// tapping it again returns to the total. When there are many categories the
/// legend lists the top rows and folds the rest into a "+N categorias" hint.
/// Shared by the Meses dashboard and the Trends "Gastos por categoria" card.
struct SpendingDonutView: View {
    @Environment(\.locale) private var locale
    let slices: [SpendingSlice]

    /// Legend rows shown before folding the tail into "+N categorias".
    var legendLimit: Int = 5
    /// Invoked when the "+N categorias" row is tapped (e.g. open the expense
    /// detail sheet). When `nil` the row is informational only.
    var onShowAll: (() -> Void)? = nil

    /// Drives the entrance animation: the ring spins and scales in, then the
    /// center total fades up. Replays when the slice set changes (e.g. switching
    /// months) so the donut feels alive rather than static.
    @State private var appeared = false

    /// Currently focused slice; `nil` shows the month total in the center.
    @State private var selectedID: UUID?

    private var total: Decimal { slices.reduce(0) { $0 + $1.amount } }

    private var selectedSlice: SpendingSlice? {
        selectedID.flatMap { id in slices.first { $0.id == id } }
    }

    /// Identity of the current slice set — animation replays when this changes.
    private var sliceKey: [UUID] { slices.map(\.id) }

    private var selectionSpring: Animation { .spring(response: 0.35, dampingFraction: 0.75) }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            donut
            legend
        }
        .onAppear {
            appeared = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                appeared = true
            }
        }
        .onChange(of: sliceKey) { _, _ in
            appeared = false
            selectedID = nil
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Valor", slice.value),
                innerRadius: .ratio(0.68),
                outerRadius: .ratio(slice.id == selectedID ? 1.0 : 0.92),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(slice.color)
            .opacity(selectedID == nil || slice.id == selectedID ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        // Manual hit-testing instead of `chartAngleSelection` — the built-in
        // selection gesture doesn't fire reliably for taps in this layout.
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, proxy: proxy, geo: geo)
                    }
            }
        }
        .rotationEffect(.degrees(appeared ? 0 : -120))
        .scaleEffect(appeared ? 1 : 0.55)
        .opacity(appeared ? 1 : 0)
        .frame(width: 130, height: 130)
        .overlay { center }
        .accessibilityLabel("Para onde foi")
    }

    /// Center readout: the focused category's name/value/share, or the total.
    private var center: some View {
        VStack(spacing: 1) {
            Text(selectedSlice.map { CategoryLocalization.display($0.name, locale: locale) } ?? "Total")
                .font(.system(size: 10, weight: .regular))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text((selectedSlice?.amount ?? total).brl)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let selectedSlice {
                Text(share(selectedSlice.amount))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 82)
        .contentShape(Circle())
        .onTapGesture {
            guard selectedID != nil else { return }
            withAnimation(selectionSpring) { selectedID = nil }
        }
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selectedID == nil ? [] : .isButton)
    }

    /// Resolves a tap on the chart to a slice: converts the point to a
    /// clockwise-from-12-o'clock angle (how `SectorMark` lays slices out) and
    /// walks the cumulative values. A tap inside the hole clears the focus;
    /// taps outside the ring are ignored.
    private func handleTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geo[plotFrame]
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let radius = (dx * dx + dy * dy).squareRoot()
        let outer = min(frame.width, frame.height) / 2
        guard radius <= outer else { return }
        guard radius >= outer * 0.6 else {
            withAnimation(selectionSpring) { selectedID = nil }
            return
        }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let totalValue = slices.reduce(0.0) { $0 + $1.value }
        guard totalValue > 0,
              let tapped = slice(atAngleValue: angle / (2 * .pi) * totalValue) else { return }
        withAnimation(selectionSpring) {
            selectedID = selectedID == tapped.id ? nil : tapped.id
        }
    }

    /// Maps a tap's angle-domain value (cumulative plotted value) to its slice.
    private func slice(atAngleValue value: Double) -> SpendingSlice? {
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.value
            if value <= cumulative { return slice }
        }
        return slices.last
    }

    // MARK: - Legend

    /// Categories folded out of the legend (never fold just one — a single
    /// extra row is shorter than the "+1 categoria" hint would be).
    private var hiddenLegendCount: Int {
        slices.count > legendLimit + 1 ? slices.count - legendLimit : 0
    }

    private var legendSlices: [SpendingSlice] {
        guard hiddenLegendCount > 0 else { return slices }
        var visible = Array(slices.prefix(legendLimit))
        // A slice focused from the ring must always have a visible legend row:
        // when the selection lives in the folded tail, it borrows the last
        // visible slot while focused (reverts on deselect).
        if let selectedSlice, !visible.contains(where: { $0.id == selectedSlice.id }) {
            visible[visible.count - 1] = selectedSlice
        }
        return visible
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(legendSlices) { slice in
                legendRow(slice)
            }
            if hiddenLegendCount > 0 {
                moreRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ slice: SpendingSlice) -> some View {
        let isSelected = slice.id == selectedID
        return Button {
            withAnimation(selectionSpring) {
                selectedID = isSelected ? nil : slice.id
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(slice.color)
                    .frame(width: 9, height: 9)
                Text(CategoryLocalization.display(slice.name, locale: locale))
                    .font(isSelected ? .caption.weight(.semibold) : .caption)
                    .lineLimit(1)
                Spacer(minLength: 1)
                Text(Money.compact(slice.amount))
                    .font(.caption2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(share(slice.amount))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 30, alignment: .trailing)
                    .layoutPriority(1)
            }
            .opacity(selectedID == nil || isSelected ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Tail of the legend when categories overflow. The ring still plots all
    /// of them; this row just says how many rows were folded and, when a
    /// handler is provided, links to the full breakdown.
    private var moreRow: some View {
        Group {
            if let onShowAll {
                Button(action: onShowAll) {
                    moreLabel(interactive: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                moreLabel(interactive: false)
            }
        }
    }

    private func moreLabel(interactive: Bool) -> some View {
        HStack(spacing: 8) {
            Text("+\(hiddenLegendCount) categorias")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 1)
            if interactive {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func share(_ amount: Decimal) -> String {
        guard total > 0 else { return "" }
        let ratio = NSDecimalNumber(decimal: amount / total).doubleValue
        return Money.formatPercent(ratio, fractionDigits: 0)
    }
}

#Preview {
    let slices: [SpendingSlice] = [
        SpendingSlice(id: UUID(), name: "Alimentacao", amount: 6180, color: .orange),
        SpendingSlice(id: UUID(), name: "Crédito", amount: 4500, color: .pink),
        SpendingSlice(id: UUID(), name: "Mercado", amount: 2000, color: .blue),
        SpendingSlice(id: UUID(), name: "Contas", amount: 1550, color: .teal),
        SpendingSlice(id: UUID(), name: "Transporte", amount: 900, color: .indigo),
        SpendingSlice(id: UUID(), name: "Lazer", amount: 700, color: .purple),
        SpendingSlice(id: UUID(), name: "Saúde", amount: 420, color: .mint),
        SpendingSlice(id: UUID(), name: "Assinaturas", amount: 180, color: .brown),
    ]

    return SpendingDonutView(slices: slices, onShowAll: {})
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding()
}
