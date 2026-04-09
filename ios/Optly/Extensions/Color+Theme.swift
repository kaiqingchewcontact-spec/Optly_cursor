//
//  Color+Theme.swift
//  Optly
//
//  Semantic colors and gradients with light/dark variants (SwiftUI).
//

#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

public enum OptlyTheme {

    // MARK: Base palette

    public static let primaryIndigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    public static let primaryPurple = Color(red: 0.55, green: 0.36, blue: 0.96)
    public static let accentTeal = Color(red: 0.08, green: 0.72, blue: 0.68)
    public static let alertOrange = Color(red: 0.96, green: 0.58, blue: 0.25)
    public static let successGreen = Color(red: 0.20, green: 0.78, blue: 0.35)

    // MARK: Semantic (adapts in dark mode)

    public static let primary: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.42, blue: 0.98, alpha: 1)
                : UIColor(red: 0.31, green: 0.27, blue: 0.90, alpha: 1)
        }
    )

    public static let primarySecondary: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.62, green: 0.48, blue: 0.99, alpha: 1)
                : UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)
        }
    )

    public static let accent: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.25, green: 0.82, blue: 0.78, alpha: 1)
                : UIColor(red: 0.08, green: 0.72, blue: 0.68, alpha: 1)
        }
    )

    public static let alert: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.99, green: 0.65, blue: 0.35, alpha: 1)
                : UIColor(red: 0.96, green: 0.58, blue: 0.25, alpha: 1)
        }
    )

    public static let success: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.86, blue: 0.52, alpha: 1)
                : UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        }
    )

    public static let background: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
                : UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1)
        }
    )

    public static let elevatedSurface: Color = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1)
                : UIColor.white
        }
    )

    // MARK: Gradients

    public static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryIndigo, primaryPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var accentGlowGradient: LinearGradient {
        LinearGradient(
            colors: [accentTeal.opacity(0.9), primaryPurple.opacity(0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public static var subtleBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, elevatedSurface.opacity(0.95)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
