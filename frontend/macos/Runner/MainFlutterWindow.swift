import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  /// The app's title bar, and the band the system's three buttons are centred
  /// in (docs/design/00-design-system.md §5).
  private let titleBarHeight: CGFloat = 48
  /// The close button's distance from the window's left edge.
  private let buttonsInset: CGFloat = 16

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // No native title bar from the first frame: the app draws its own and
    // keeps only the system's buttons (window_manager sets the same style
    // again when the app starts).
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)

    // AppKit puts the buttons back at its own place whenever it lays the
    // title bar out again.
    for name in [
      NSWindow.didResizeNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResignKeyNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(layOutWindowButtons), name: name, object: self)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    layOutWindowButtons()
  }

  /// Keeps the window hidden until the app shows it, once its title bar is set
  /// (window_manager's "hidden at launch").
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  /// Puts the close button 16 px from the left edge and centres the three
  /// buttons in the 48 px band, keeping the system's spacing between them.
  @objc private func layOutWindowButtons() {
    guard !styleMask.contains(.fullScreen),
      let close = standardWindowButton(.closeButton),
      let minimize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let titleBarContainer = close.superview?.superview
    else { return }

    var container = titleBarContainer.frame
    container.size.height = titleBarHeight
    container.origin.y = frame.height - titleBarHeight
    titleBarContainer.frame = container

    let pitch = minimize.frame.minX - close.frame.minX
    for (index, button) in [close, minimize, zoom].enumerated() {
      button.setFrameOrigin(
        NSPoint(
          x: buttonsInset + CGFloat(index) * pitch,
          y: (titleBarHeight - button.frame.height) / 2))
    }
  }
}
