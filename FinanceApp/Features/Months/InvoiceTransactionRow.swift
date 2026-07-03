import SwiftUI

/// One line in the invoice review list: merchant, date, installment badge, the
/// assigned category (or a prompt to categorize), and the amount.
struct InvoiceTransactionRow: View {
    @Environment(\.locale) private var locale
    let transaction: InvoiceTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.rawDescription)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if transaction.isInstallment {
                        Text("\(transaction.installmentCurrent)/\(transaction.installmentTotal)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.recurring.opacity(0.16)))
                            .foregroundStyle(Theme.recurring)
                    }
                }

                HStack(spacing: 6) {
                    Text(transaction.postedDate.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale)))
                    if !transaction.isFee {
                        Text("·")
                        categoryLabel
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(Money.formatSigned(transaction.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.amount < 0 ? Theme.income : .primary)

            if !transaction.isFee {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var categoryLabel: some View {
        if let category = transaction.category {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 9))
                CategoryNameText(category.name)
            }
            .foregroundStyle(Theme.tint(for: category.id))
        } else {
            Text("Toque para categorizar")
                .foregroundStyle(Theme.oneOff)
        }
    }
}
