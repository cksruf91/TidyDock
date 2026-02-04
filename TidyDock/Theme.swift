import SwiftUI

enum TidyTheme {
    static let lightCanvasTop = Color(red: 0.65, green: 0.74, blue: 0.94)
    static let lightCanvasBottom = Color(red: 0.85, green: 0.89, blue: 0.95)
    static let lightPanel = Color(red: 0.92, green: 0.95, blue: 0.99)
    static let lightCard = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let lightHighlight = Color(red: 0.78, green: 0.85, blue: 0.98)
    static let lightHighlightNavy = Color(red: 0.10, green: 0.16, blue: 0.30)
    static let lightStroke = Color.white.opacity(0.0)
    static let sidebarNavy = Color(red: 0.07, green: 0.10, blue: 0.20)
    static let sidebarHighlight = Color(red: 0.72, green: 0.84, blue: 0.98)

    static let darkCanvasTop = Color(red: 0.12, green: 0.15, blue: 0.20)
    static let darkCanvasBottom = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let darkPanel = Color.white.opacity(0.06)
    static let darkCard = Color.white.opacity(0.10)
    static let darkHighlight = Color.blue.opacity(0.25)
    static let darkStroke = Color.white.opacity(0.15)

    @ViewBuilder
    static func canvasBackground(for colorScheme: ColorScheme) -> some View {
        if colorScheme == .light {
            ZStack {
                LinearGradient(
                    colors: [lightCanvasTop, lightCanvasBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.orange.opacity(0.18), Color.clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 320
                )
            }
        } else {
            LinearGradient(
                colors: [darkCanvasTop, darkCanvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct TidyPanelBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = 20
        let fill = colorScheme == .light ? TidyTheme.lightPanel : TidyTheme.darkPanel
        let stroke = colorScheme == .light ? TidyTheme.lightStroke : TidyTheme.darkStroke

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .shadow(color: Color.black.opacity(colorScheme == .light ? 0.15 : 0.35), radius: 18, x: 6, y: 10)
                    .shadow(color: Color.white.opacity(colorScheme == .light ? 0.85 : 0.08), radius: 12, x: -6, y: -6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke)
            )
    }
}

extension View {
    func tidyPanelBackground() -> some View {
        modifier(TidyPanelBackground())
    }
}
