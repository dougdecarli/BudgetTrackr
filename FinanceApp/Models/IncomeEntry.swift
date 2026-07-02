import Foundation
import SwiftData

@Model
final class IncomeEntry {
    var id: UUID = UUID()
    var month: Month? = nil
    var source: IncomeSource? = nil
    var amount: Decimal = Decimal(0)

    init(
        id: UUID = UUID(),
        month: Month? = nil,
        source: IncomeSource? = nil,
        amount: Decimal = 0
    ) {
        self.id = id
        self.month = month
        self.source = source
        self.amount = amount
    }
}
