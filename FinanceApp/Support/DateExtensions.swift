import Foundation

extension Date {
    static var currentMonthAnchor: Date {
        Date().monthAnchor
    }

    var monthAnchor: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    var previousMonthAnchor: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? self
    }

    var nextMonthAnchor: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? self
    }

    var monthLabelPtBR: String {
        let formatter = DateFormatter()
        formatter.locale = Money.locale
        formatter.dateFormat = "LLLL yyyy"
        let raw = formatter.string(from: self)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    /// Standalone, capitalized month name, e.g. "Junho". Paired with `yearLabel`
    /// so the month header can weight the name and year differently.
    var monthNamePtBR: String {
        let formatter = DateFormatter()
        formatter.locale = Money.locale
        formatter.dateFormat = "LLLL"
        let raw = formatter.string(from: self)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    var yearLabel: String {
        String(Calendar.current.component(.year, from: self))
    }

    var shortMonthLabelPtBR: String {
        let formatter = DateFormatter()
        formatter.locale = Money.locale
        formatter.dateFormat = "LLL/yy"
        return formatter.string(from: self)
    }
}
