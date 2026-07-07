import Foundation
import SwiftUI

enum IncomeType: String, Codable, CaseIterable {
    case income
    case bonus
    case benefit
    case tax
    case other

    var displayName: LocalizedStringKey {
        switch self {
        case .income:  return "Renda"
        case .bonus:   return "Bônus"
        case .benefit: return "Benefício"
        case .tax:     return "Imposto"
        case .other:   return "Outros"
        }
    }

    /// Types a user can assign to an income source. `.tax` stays in the enum for
    /// backward compatibility with existing data but is no longer offered.
    static var selectableCases: [IncomeType] { [.income, .bonus, .benefit, .other] }
}
