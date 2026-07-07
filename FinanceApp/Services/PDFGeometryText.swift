import PDFKit
import Foundation

/// Reconstructs an invoice PDF's text in correct reading order using PDFKit's
/// layout-aware line selections.
///
/// `PDFDocument.string` returns text in the PDF's internal draw order, which for
/// multi-column statements (notably some Itaú "Black" layouts) interleaves the
/// charges table with the credit-limit / interest sidebars — amounts end up
/// attached to the wrong rows, or the section markers land out of order and the
/// parser reads zero transactions. Reading `selectionsByLine()` with each line's
/// on-page position lets us split every page at its column gutter and re-emit
/// each column top-to-bottom, so a charge and its amount stay on the same row.
///
/// Used as a fallback: the importer tries `document.string` first (correct for
/// single-column statements) and only reconstructs when that yields no
/// transactions, so well-behaved layouts are untouched.
enum PDFGeometryText {
    /// One layout-aware text line with its bounding box on the page.
    private struct Line { var minX: Double; var maxX: Double; var y: Double; var s: String }

    static func reconstruct(document: PDFDocument) -> String {
        var out: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            out.append(contentsOf: reconstruct(page: page))
        }
        return out.joined(separator: "\n")
    }

    private static func reconstruct(page: PDFPage) -> [String] {
        let box = page.bounds(for: .mediaBox)
        guard let full = page.selection(for: box) else { return [] }
        let pageWidth = Double(box.width)

        let lines: [Line] = full.selectionsByLine().compactMap { sel in
            let s = (sel.string ?? "").trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { return nil }
            let r = sel.bounds(for: page)
            return Line(minX: Double(r.minX), maxX: Double(r.maxX), y: Double(r.minY), s: s)
        }
        guard !lines.isEmpty else { return [] }

        // Table cells are narrow; wide prose lines would mask the gutter.
        let narrow = lines.filter { ($0.maxX - $0.minX) < pageWidth * 0.5 }
        guard let gutter = gutter(in: narrow, pageWidth: pageWidth) else {
            return mergeRows(lines) // single column
        }
        let left = lines.filter { ($0.minX + $0.maxX) / 2 < gutter }
        let right = lines.filter { ($0.minX + $0.maxX) / 2 >= gutter }
        return mergeRows(left) + mergeRows(right)
    }

    /// Merges line-fragments sharing a row (close `y`) into one string ordered
    /// left→right, then orders the rows top→bottom. This is what pulls a charge's
    /// amount (a separate selection to its right) back onto the charge's line.
    private static func mergeRows(_ lines: [Line]) -> [String] {
        let sorted = lines.sorted { $0.y > $1.y }
        var rows: [String] = []
        var i = 0
        while i < sorted.count {
            var group = [sorted[i]]
            var j = i + 1
            while j < sorted.count && abs(sorted[j].y - sorted[i].y) < 5 {
                group.append(sorted[j]); j += 1
            }
            group.sort { $0.minX < $1.minX }
            rows.append(group.map(\.s).joined(separator: " "))
            i = j
        }
        return rows
    }

    /// The mid-page column gutter: the x with the fewest lines crossing it,
    /// tolerant of a stray prose line that bridges the columns. Returns its
    /// midpoint, or nil when the page is effectively single-column.
    private static func gutter(in lines: [Line], pageWidth: Double) -> Double? {
        guard lines.count >= 6 else { return nil }
        let lo = Int(pageWidth * 0.28), hi = Int(pageWidth * 0.72)
        guard hi > lo else { return nil }
        func crossings(_ x: Double) -> Int {
            lines.reduce(0) { $0 + (($1.minX - 1 <= x && x <= $1.maxX + 1) ? 1 : 0) }
        }
        let counts: [(x: Int, c: Int)] = (lo...hi).map { ($0, crossings(Double($0))) }
        guard let minC = counts.map(\.c).min(), let maxC = counts.map(\.c).max() else { return nil }
        // Needs a real two-sided density contrast, and a gutter that is nearly
        // empty (at most a stray line or two crossing it).
        guard maxC - minC >= 4, minC <= 2 else { return nil }
        // Longest run of near-minimum crossings → its midpoint is the gutter.
        var bestStart = 0, bestLen = 0, runStart: Int? = nil
        for (i, entry) in counts.enumerated() {
            if entry.c <= minC + 1 {
                if runStart == nil { runStart = i }
                let len = i - runStart! + 1
                if len > bestLen { bestLen = len; bestStart = runStart! }
            } else {
                runStart = nil
            }
        }
        guard bestLen >= 8 else { return nil }
        return Double(counts[bestStart].x) + Double(bestLen) / 2
    }
}
