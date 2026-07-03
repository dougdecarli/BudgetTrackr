import SwiftUI

/// Shows where the month's money went as a donut chart with a legend, using the
/// shared `SpendingDonutView`. Renders nothing when there's no spending.
struct CategoryBreakdownCard: View {
    let month: Month

    private var slices: [SpendingSlice] {
        SpendingDonut.slices(from: SummaryMath.categoryBreakdown(for: month))
    }

    var body: some View {
        if !slices.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Para onde foi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                SpendingDonutView(slices: slices)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}
