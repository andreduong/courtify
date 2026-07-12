import SwiftUI

enum WidgetTheme {
    static let midnightGreen = Color(red: 10 / 255, green: 18 / 255, blue: 13 / 255)
    static let opticYellow = Color(red: 204 / 255, green: 1, blue: 0)
    static let emeraldGreen = Color(red: 0, green: 112 / 255, blue: 60 / 255)

    static func roundedFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    static func roundedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
