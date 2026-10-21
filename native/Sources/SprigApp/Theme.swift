import AppKit
import CoreText
import SprigCore
import SwiftUI

enum Theme {
  static func colour(_ name: String, _ hex: UInt32) -> Color {
    if let colour = NSColor(named: NSColor.Name(name), bundle: .sprigResources) {
      return Color(nsColor: colour)
    }
    return Color(
      red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255)
  }
  static let background = colour("SprigBackground", 0xf6f7f3), ink = colour("SprigInk", 0x292d2b),
    muted = colour("SprigMuted", 0x737974), accent = colour("AccentColor", 0x537453)
  static func font(_ size: CGFloat = 13, _ weight: Font.Weight = .regular) -> Font {
    let style =
      weight == .bold
      ? "Bold" : weight == .semibold ? "SemiBold" : weight == .medium ? "Medium" : "Regular"
    return .custom(
      "Inter-\(style)", size: size,
      relativeTo: size >= 24 ? .title : size >= 16 ? .headline : size <= 11 ? .caption : .body)
  }
  static func registerFonts() {
    guard let root = Bundle.sprigResources.resourceURL?.appending(path: "Fonts"),
      let urls = try? FileManager.default.contentsOfDirectory(
        at: root, includingPropertiesForKeys: nil)
    else { return }
    for url in urls where url.pathExtension == "woff" {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}
extension NoteColour {
  var fill: Color { Theme.colour(rawValue.capitalized, hex) }
  var hex: UInt32 {
    switch self {
    case .butter: 0xfbf0bf
    case .sage: 0xe6eedb
    case .rose: 0xf5e2df
    case .lilac: 0xeae5f5
    case .apricot: 0xf0d9bd
    }
  }
  var css: String { String(format: "#%06x", hex) }
}
struct FigmaIcon: View {
  let name: String
  var group: String = "detail0"
  var size: CGFloat = 20
  var selected: Bool? = nil
  var body: some View {
    if let image = FigmaIconCache.image(name: name, group: group, selected: selected) {
      Image(nsImage: image).frame(width: size, height: size).accessibilityHidden(true)
    }
  }
}
struct GlassSurface: ViewModifier {
  var radius: CGFloat = 24
  @Environment(\.accessibilityReduceTransparency) private var reducedTransparency
  func body(content: Content) -> some View {
    content
      .background(
        reducedTransparency ? Color.white : Color.white.opacity(0.2),
        in: RoundedRectangle(cornerRadius: radius)
      )
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
      .overlay(
        RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.85), lineWidth: 1)
      )
      .shadow(color: Color(red: 0.15, green: 0.2, blue: 0.16).opacity(0.1), radius: 9, x: 0, y: 5)
  }
}
extension View {
  func sprigGlass(_ radius: CGFloat = 24) -> some View { modifier(GlassSurface(radius: radius)) }
}
struct Caption: View {
  let text: String
  init(_ text: String) { self.text = text }
  var body: some View { Text(text).font(Theme.font(11)).foregroundStyle(Theme.muted) }
}
struct PillButton: View {
  var title: String
  var width: CGFloat = 152
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(Theme.font(12, .medium)).foregroundStyle(Theme.accent).frame(
        width: width, height: 40)
    }.buttonStyle(SprigButtonStyle()).sprigGlass(22)
  }
}

// These are new interaction animations, independent of the static Figma reference.
enum SprigMotion {
  static let testingReduction = ProcessInfo.processInfo.environment["SPRIG_REDUCE_MOTION"] == "1"
  static func isReduced(system: Bool) -> Bool { system || testingReduction }
  static let settle = Animation.spring(response: 0.36, dampingFraction: 0.86)
  static let quick = Animation.spring(response: 0.22, dampingFraction: 0.9)
  static let fade = Animation.easeInOut(duration: 0.16)
}
struct SprigAnimated<Value: Equatable>: ViewModifier {
  let value: Value
  var animation: Animation = SprigMotion.settle
  @Environment(\.accessibilityReduceMotion) private var systemReduced
  private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
  func body(content: Content) -> some View {
    content.animation(reduced ? nil : animation, value: value)
  }
}
extension View {
  func sprigAnimate<Value: Equatable>(_ value: Value, animation: Animation = SprigMotion.settle)
    -> some View
  { modifier(SprigAnimated(value: value, animation: animation)) }
}
struct SprigButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    SprigButtonBody(configuration: configuration)
  }
  private struct SprigButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
    var body: some View {
      configuration.label
        .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.38)
        .scaleEffect(reduced || !enabled ? 1 : configuration.isPressed ? 0.97 : hovered ? 1.015 : 1)
        .onHover { hovered = $0 }
        .sprigAnimate(configuration.isPressed, animation: SprigMotion.quick)
        .sprigAnimate(hovered, animation: SprigMotion.quick)
    }
  }
}

@MainActor private enum FigmaIconCache {
  static let cache = NSCache<NSString, NSImage>()
  static func image(name: String, group: String, selected: Bool?) -> NSImage? {
    let resource = "\(group)-imgIcon\(name)"
    let key = "\(resource)-\(selected.map(String.init) ?? "original")" as NSString
    if let cached = cache.object(forKey: key) { return cached }
    guard
      let url = Bundle.sprigResources.url(
        forResource: resource, withExtension: "svg", subdirectory: "Assets")
    else { return nil }
    let image: NSImage?
    if let selected, var svg = try? String(contentsOf: url, encoding: .utf8) {
      // Navigation uses the original Figma paths with an explicit per-button state.
      svg = svg.replacingOccurrences(of: "#414942", with: selected ? "#537453" : "#414942")
      if selected {
        svg = svg.replacingOccurrences(of: "<path ", with: "<path fill=\"#537453\" ")
      }
      image = NSImage(data: Data(svg.utf8))
    } else {
      image = NSImage(contentsOf: url)
    }
    guard let image else { return nil }
    cache.setObject(image, forKey: key)
    return image
  }
}

extension RopeColour {
  var tint: Color {
    switch self {
    case .sage: Theme.accent
    case .rose: Color(red: 0.72, green: 0.37, blue: 0.43)
    case .blue: Color(red: 0.30, green: 0.49, blue: 0.72)
    case .lilac: Color(red: 0.54, green: 0.43, blue: 0.71)
    case .amber: Color(red: 0.72, green: 0.51, blue: 0.22)
    case .charcoal: Theme.ink
    }
  }
}
