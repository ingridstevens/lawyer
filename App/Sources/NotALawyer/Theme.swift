import AppKit
import SwiftUI

/// The app's look: an annotated statute. Section numbers sit in a margin in DIN, the typeface
/// of German signs and forms; law text is set in a serif like printed law; quoted words get a
/// highlighter.
enum Theme {
    // MARK: Colour

    /// Body text ink.
    static let ink = dynamic(light: 0x1F2633, dark: 0xE4E7EE)
    /// The violet-blue of an office rubber stamp. Section numbers, links, the send button.
    static let stamp = dynamic(light: 0x3846C4, dark: 0x9AA5FF)
    /// Behind quoted words.
    static let highlighter = dynamic(light: 0xF5E15A, dark: 0xF5E15A, darkAlpha: 0.32)
    /// Warnings: stale laws, unsupported language.
    static let amber = dynamic(light: 0xB86E00, dark: 0xF0A73A)
    /// The sheet that law text sits on.
    static let sheet = dynamic(light: 0xFFFFFF, dark: 0x24272D)
    static let rule = dynamic(light: 0xD9DCE3, dark: 0x3A3E46)


    private static func dynamic(light: UInt32, dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark, alpha: darkAlpha) : NSColor(hex: light)
        })
    }

    // MARK: Type

    /// Margin section numbers.
    static func margin(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("DINCondensed-Bold", size: size, relativeTo: style)
    }

    /// Law text and questions.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    // MARK: Layout

    /// Width of the margin gutter that holds section numbers.
    static let gutter: CGFloat = 76
    /// Reading column, excluding the gutter. Keeps lines under ~80 characters.
    static let column: CGFloat = 640
    /// Gutter plus column: the width of a centred page.
    static let pageWidth: CGFloat = gutter + 18 + column
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Lays out content with a left margin, like an annotated statute.
struct MarginRow<Margin: View, Content: View>: View {
    @ViewBuilder var margin: Margin
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            margin
                .frame(width: Theme.gutter, alignment: .trailing)
                .padding(.trailing, 18)
            content
                .frame(maxWidth: Theme.column, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MarginRow where Margin == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.margin = EmptyView()
        self.content = content()
    }
}

// MARK: Pieces

/// A headline in the serif.
struct Headline: View {
    let text: String
    var style: Font.TextStyle = .largeTitle
    var size: CGFloat? = nil

    var body: some View {
        Text(text)
            .font(size.map { .system(size: $0, weight: .semibold, design: .serif) } ?? Theme.serif(style, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A small bold section label.
struct Pill: View {
    let text: String

    var body: some View {
        Text(text).font(.headline)
    }
}

/// The page background.
struct PageBackground: View {
    var body: some View {
        Theme.sheet.ignoresSafeArea()
    }
}
