import AppKit
import Combine
import SwiftUI

/// Owns the borderless, click-through window that sits on top of the
/// notch and hosts the critter's SwiftUI view.
final class NotchWindowController: NSWindowController {
    let critterState = CritterState()

    private var expansionCancellable: AnyCancellable?

    // Physical notch pixels can never be drawn to (real cutout in the
    // panel, not a masked area), so the resting frame must match the
    // notch height exactly. Expansion has to grow *downward* past the
    // notch's bottom edge into the real menu-bar strip, not grow in place,
    // or the content stays hidden behind the cutout.
    private let notchWidth: CGFloat = 200
    private let fallbackNotchHeight: CGFloat = 32
    // Needs to clear the rendered height of the expanded emoji glyph
    // (CritterView currently uses a 50pt font, ~50pt tall), not just be a
    // stylistic "widen a bit" amount, or the top of the glyph still lands
    // inside the notch cutout.
    private let expandedExtraHeight: CGFloat = 56

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
        updateWindowFrame(expanded: critterState.isExpanded)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        expansionCancellable = critterState.$isExpanded.sink { [weak self] expanded in
            self?.updateWindowFrame(expanded: expanded)
        }
    }

    @objc private func handleScreenParametersChanged() {
        updateWindowFrame(expanded: critterState.isExpanded)
    }

    /// Sizes and positions the window over the built-in display's notch
    /// area, anchored to the notch's top edge. At rest, height matches the
    /// notch exactly (fully hidden behind the physical cutout). Expanded,
    /// it grows downward past the notch into the real, drawable menu-bar
    /// strip so the critter is actually visible. Falls back to a small
    /// top-center strip on notchless screens so the critter is still
    /// visible during development.
    private func updateWindowFrame(expanded: Bool) {
        guard let window, let screen = NSScreen.main else { return }

        let topInset = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : fallbackNotchHeight
        let height = expanded ? topInset + expandedExtraHeight : topInset

        let frame = NSRect(
            x: screen.frame.midX - notchWidth / 2,
            y: screen.frame.maxY - height,
            width: notchWidth,
            height: height
        )
        window.setFrame(frame, display: true, animate: true)
    }
}
