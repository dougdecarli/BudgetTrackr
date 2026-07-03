import SwiftUI

/// Single income-vs-spending progress bar for the hero card. Turns the abstract
/// net number into a glanceable "how much of this month's income is spent"
/// read. Fills green while within income, red once spending exceeds it.
struct SpendBar: View {
    let income: Decimal
    let spending: Decimal

    private var ratio: Double {
        guard income > 0 else { return spending > 0 ? 1 : 0 }
        let value = NSDecimalNumber(decimal: spending / income).doubleValue
        return min(max(value, 0), 1)
    }

    private var overspent: Bool { income > 0 && spending > income }
    private var available: Decimal { max(income - spending, 0) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(overspent ? Theme.spending : Theme.income)
                        .frame(width: max(spending > 0 ? 8 : 0, geo.size.width * ratio))
                }
            }
            .frame(height: 8)

            HStack(spacing: 4) {
                Text(Money.formatPercent(ratio, fractionDigits: 0)).monospacedDigit()
                Text("gasto")
                Spacer()
                if overspent {
                    Text("Acima da renda").foregroundStyle(Theme.spending)
                } else {
                    Text("disponível")
                    Text(available.brl).monospacedDigit()
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
