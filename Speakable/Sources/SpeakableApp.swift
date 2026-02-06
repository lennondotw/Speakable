import SwiftUI

@main
struct SpeakableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuBarView()
    } label: {
      #if DEBUG
      Image(nsImage: Self.makeDebugMenuBarIcon())
      #else
      Image(systemName: "waveform")
      #endif
    }

    Window("Settings", id: "settings") {
      SettingsView()
        .frame(minWidth: 600, maxWidth: 600, minHeight: 400, maxHeight: .infinity)
    }
    .defaultSize(width: 600, height: 500)
    .windowResizability(.contentSize)
  }

  #if DEBUG
  /// Creates a menu bar icon with a small yellow indicator dot for debug builds.
  /// Uses SF Symbol palette rendering with `NSColor.labelColor` so the waveform
  /// adapts to the menu bar appearance, while the dot stays yellow.
  private static func makeDebugMenuBarIcon() -> NSImage {
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      .applying(.init(paletteColors: [.labelColor]))

    guard let waveform = NSImage(
      systemSymbolName: "waveform",
      accessibilityDescription: "Speakable"
    )?.withSymbolConfiguration(symbolConfig) else {
      return NSImage(systemSymbolName: "waveform", accessibilityDescription: "Speakable")!
    }

    let dotDiameter: CGFloat = 5
    let cutoutPadding: CGFloat = 1.5
    let cutoutDiameter = dotDiameter + cutoutPadding * 2
    let baseSize = waveform.size

    // Dot center at bottom-right corner
    let dotCenter = NSPoint(
      x: baseSize.width - dotDiameter / 2,
      y: dotDiameter / 2
    )

    let image = NSImage(size: baseSize, flipped: false) { _ in
      guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

      // 1) Draw waveform
      waveform.draw(in: NSRect(origin: .zero, size: baseSize))

      // 2) Punch out a circular cutout around the dot using .clear blend mode
      ctx.setBlendMode(.clear)
      ctx.fillEllipse(in: CGRect(
        x: dotCenter.x - cutoutDiameter / 2,
        y: dotCenter.y - cutoutDiameter / 2,
        width: cutoutDiameter,
        height: cutoutDiameter
      ))

      // 3) Draw the yellow dot on top
      ctx.setBlendMode(.normal)
      ctx.setFillColor(NSColor.systemYellow.cgColor)
      ctx.fillEllipse(in: CGRect(
        x: dotCenter.x - dotDiameter / 2,
        y: dotCenter.y - dotDiameter / 2,
        width: dotDiameter,
        height: dotDiameter
      ))

      return true
    }

    // Non-template to preserve the yellow dot color
    image.isTemplate = false
    return image
  }
  #endif
}
