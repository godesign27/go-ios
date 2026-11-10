import SwiftUI
import UIKit

/// GO's designed text sizes, scaled with the person's Dynamic Type setting.
///
/// Classic Launcher uses exact sizes (and the theme's font design) for its look; `.system(size:)`
/// alone ignores Settings › Display & Brightness › Text Size. This scales each size the same way
/// iOS scales the text style it sits next to, with an optional ceiling where space is fixed
/// (icon labels, square cards).
struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let textStyle: Font.TextStyle
    let maxSize: CGFloat?

    func body(content: Content) -> some View {
        content.font(.system(size: Self.scaled(size, style: textStyle, dynamicTypeSize: dynamicTypeSize, max: maxSize), weight: weight, design: design))
    }

    static func scaled(_ size: CGFloat, style: Font.TextStyle, dynamicTypeSize: DynamicTypeSize, max: CGFloat? = nil) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let value = UIFontMetrics(forTextStyle: style.uiKit).scaledValue(for: size, compatibleWith: traits)
        return min(value, max ?? .greatestFiniteMagnitude)
    }
}

extension View {
    /// `.font(.system(size:weight:design:))` that follows Dynamic Type.
    /// - Parameters:
    ///   - relativeTo: the text style this size behaves like (how fast it grows).
    ///   - maxSize: ceiling for places with fixed room.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body,
        maxSize: CGFloat? = nil
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, textStyle: textStyle, maxSize: maxSize))
    }
}

extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

extension ShapeStyle where Self == Color {
    /// Secondary text for GO's own screens: the label color at 72%, about 7:1 on white and
    /// on dark grouped backgrounds. The system .secondary measured just under 4.5:1 in
    /// Xcode's accessibility audit.
    static var secondaryText: Color { Color.primary.opacity(0.72) }
}
