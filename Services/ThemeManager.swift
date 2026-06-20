import SwiftUI

/// Manages app-wide theme preferences (color scheme + accent color).
final class ThemeManager: ObservableObject {

    // MARK: - Theme

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case dark   = "Dark"
        case light  = "Light"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .dark:   return .dark
            case .light:  return .light
            }
        }
    }

    // MARK: - Accent Color

    enum AccentOption: String, CaseIterable, Identifiable {
        case green  = "Green"
        case blue   = "Blue"
        case purple = "Purple"
        case orange = "Orange"

        var id: String { rawValue }

        var hex: String {
            switch self {
            case .green:  return "00E08F"
            case .blue:   return "5B86E5"
            case .purple: return "6C5CE7"
            case .orange: return "FF8C42"
            }
        }

        var color: Color { Color(hex: hex) }
    }

    // MARK: - Stored Preferences

    @AppStorage("appTheme") var themeRawValue: String = AppTheme.dark.rawValue {
        didSet { objectWillChange.send() }
    }

    @AppStorage("accentColor") var accentRawValue: String = AccentOption.green.rawValue {
        didSet { objectWillChange.send() }
    }

    // MARK: - Computed

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRawValue) ?? .dark }
        set { themeRawValue = newValue.rawValue }
    }

    var accentOption: AccentOption {
        get { AccentOption(rawValue: accentRawValue) ?? .green }
        set { accentRawValue = newValue.rawValue }
    }

    var accentColor: Color { accentOption.color }
}
