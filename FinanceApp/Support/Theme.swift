import SwiftUI

/// Centralized visual tokens for the redesigned Meses dashboard and add flows.
/// Backgrounds still use the system grouped colors (so Dark Mode is automatic);
/// this only fixes the per-domain accent palette and shared metrics so tints
/// stay consistent across the hero, tiles, chips, and keypad.
enum Theme {
    // Per-domain tints — mirror the dashboard sections.
    static let income: Color = .green
    static let recurring: Color = .indigo
    static let oneOff: Color = .orange
    static let card: Color = .blue
    static let spending: Color = .red

    // Shared corner radii.
    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12

    /// Stable tint for a category. Categories store no color, so we map their
    /// id to a fixed palette — deterministic across launches (unlike
    /// `hashValue`, which is per-process seeded) so a chip keeps its color.
    static func tint(for id: UUID) -> Color {
        let palette: [Color] = [.orange, .pink, .teal, .indigo, .blue, .purple, .mint, .cyan, .brown, .red]
        let sum = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(0) { $0 &+ Int($1) }
        }
        return palette[sum % palette.count]
    }
}
