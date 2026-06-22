import AppKit
import SwiftUI

// MARK: - Theme
// Single source of truth for the "modern keepsake" palette and sizing constants
// used across BoardView and any future UI.

enum Theme {

    // MARK: - Map palette

    /// Soft warm paper / land fill — reminiscent of aged map linen.
    static let mapFill    = NSColor(srgbRed: 0.949, green: 0.937, blue: 0.906, alpha: 1)
    /// Subtle land border — just enough definition without visual noise.
    static let mapStroke  = NSColor(srgbRed: 0.780, green: 0.760, blue: 0.720, alpha: 1)
    /// Map border line width (pixels at 1× scale).
    static let mapLineWidth: CGFloat = 0.4

    /// Ocean / canvas background — cool off-white so the land pops softly.
    static let ocean = Color(red: 0.859, green: 0.882, blue: 0.906)

    // MARK: - Pin colours

    /// Default place pin — warm coral.
    static let pin         = Color(red: 0.929, green: 0.325, blue: 0.278)
    /// Selected place pin — richer, deeper coral.
    static let pinSelected = Color(red: 0.780, green: 0.165, blue: 0.118)
    /// Home marker ring colour — deep slate blue.
    static let home        = Color(red: 0.176, green: 0.337, blue: 0.529)

    // MARK: - Thread

    /// Thin line connecting Home → each visited place.
    static let thread      = Color(red: 0.176, green: 0.337, blue: 0.529).opacity(0.35)
    static let threadWidth: CGFloat = 0.8

    // MARK: - Sizing

    /// Radius of a normal place pin dot (points).
    static let pinRadius: CGFloat   = 5
    /// Radius of the selected place pin dot.
    static let pinRadiusSelected: CGFloat = 7
    /// Outer ring radius for the Home marker.
    static let homeRadius: CGFloat  = 6
    /// Hit-test slop — tap must land within this many points of a pin centre.
    static let hitSlop: CGFloat     = 14

    // MARK: - Corner radii / typography (for sidebar etc.)

    static let cardCornerRadius: CGFloat = 10
    static let labelFont = Font.system(size: 11, weight: .medium, design: .rounded)
}
