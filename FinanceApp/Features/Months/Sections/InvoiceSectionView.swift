import SwiftUI

struct InvoiceSectionView: View {
    let month: Month

    var body: some View {
        Section {
            if let invoice = month.invoice {
                HStack {
                    Text("Total da fatura")
                    Spacer()
                    Text(invoice.totalAmount.brl)
                        .monospacedDigit()
                }
                Text("Importada em \(invoice.uploadedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Importar fatura (em breve)", systemImage: "doc.badge.arrow.up")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Fatura do cartão")
        }
    }
}
