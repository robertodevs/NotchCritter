import AppKit
import SwiftUI

/// Owns the borderless, click-through window that sits on top of the
/// notch and hosts the critter's SwiftUI view.
final class NotchWindowController: NSWindowController {
    let critterState = CritterState()

    convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true

        self.init(window: window)
        window.contentView = NSHostingView(rootView: CritterView(state: critterState))
        positionOverNotch()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(positionOverNotch),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Sizes and positions the window over the built-in display's notch
    /// area. Falls back to a small top-center strip on notchless screens
    /// so the critter is still visible during development.
    @objc private func positionOverNotch() {
        guard let window, let screen = NSScreen.main else { return }

        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 32
        let topInset = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : notchHeight

        let frame = NSRect(
            x: screen.frame.midX - notchWidth / 2,
            y: screen.frame.maxY - topInset,
            width: notchWidth,
            height: topInset
        )
        window.setFrame(frame, display: true)
    }
}
