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
    // Needs to clear the rendered height of the expanded sprite (56pt box,
    // CritterView.swift) with a few points of margin, or the top of the
    // sprite (the character's head) still lands inside the notch cutout.
    private let expandedExtraHeight: CGFloat = 64
    // screen.safeAreaInsets.top (32pt on this hardware) turned out to be a
    // conservative/larger number than the actual non-drawable cutout —
    // confirmed by photo: a window sized to exactly match it still showed
    // the collapsed sprite peeking out below the notch. Shrinking the
    // resting height by this margin keeps it safely inside the real cutout.
    private let restingSafetyMargin: CGFloat = 14

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
        let height = expanded ? topInset + expandedExtraHeight : topInset - restingSafetyMargin

        let frame = NSRect(
            x: screen.frame.midX - notchWidth / 2,
            y: screen.frame.maxY - height,
            width: notchWidth,
            height: height
        )
        // Explicit duration (matching CritterAnimation.transitionDuration,
        // which CritterView's scale animation also uses) instead of plain
        // animate:true/false — both the window growing/shrinking and the
        // content scaling up/down start from the same isExpanded change and
        // now run over the identical duration, so they land in lockstep
        // instead of two independently-timed animations racing each other.
        // Growing uses the same accelerating "falling" curve as the content
        // scale. Shrinking stays a plain ease-out (no overshoot) — the
        // content's spring carries the "settle back" feel on that side, and
        // an overshooting window height risks a visible clip glitch right
        // as it's meant to vanish.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = CritterAnimation.transitionDuration
            context.timingFunction = expanded
                ? CAMediaTimingFunction(
                    controlPoints: Float(CritterAnimation.appearCurve.x1), Float(CritterAnimation.appearCurve.y1),
                    Float(CritterAnimation.appearCurve.x2), Float(CritterAnimation.appearCurve.y2)
                  )
                : CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        }
    }
}
