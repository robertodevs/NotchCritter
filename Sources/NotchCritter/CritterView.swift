import SwiftUI
import SpriteKit

/// Renders the critter's sprite animation, driven by CritterState's mood
/// and expansion. The SKScene owns the actual frame-by-frame animation;
/// this view just sizes it and forwards mood changes.
struct CritterView: View {
    @ObservedObject var state: CritterState

    @State private var scene = CritterSpriteScene()
    @State private var wanderOffset: CGFloat = 0
    @State private var wanderTimer: Timer?

    // How far the critter drifts from center while idle, and the pause
    // range between drifts. Small enough to stay clear of the window edges
    // (window is 200pt wide, sprite is at most 56pt).
    private let wanderRange: ClosedRange<CGFloat> = -30...30
    private let wanderPauseRange: ClosedRange<Double> = 2.5...4.5

    var body: some View {
        HStack {
            Spacer()
            // Constant frame; the grow/shrink look comes from scaleEffect,
            // animated over the same duration as the window's own height
            // animation (NotchWindowController), so they move in lockstep:
            // it scales up from nothing as the window drops it into place,
            // and hits 100% right as it arrives. Anchored at the bottom so
            // it grows from (and shrinks back into) the notch, not the
            // frame's center. Scale 0 also means it's genuinely invisible
            // at rest regardless of exactly how the window is clipping it —
            // hiding no longer depends on pixel-perfect window geometry.
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: 56, height: 56)
                .scaleEffect(state.isExpanded ? 1.0 : 0.0, anchor: .bottom)
                // Appear: accelerating curve, so it feels like it's actually
                // falling out of the notch rather than smoothly easing in.
                // Hide: a slightly underdamped spring for an "ease out back"
                // snap — settles with a small bounce instead of a flat stop.
                // dampingFraction 0.7 keeps the overshoot mild (scale dips
                // only a little below 0) rather than visibly flipping.
                .animation(
                    state.isExpanded
                        ? .timingCurve(
                            CritterAnimation.appearCurve.x1, CritterAnimation.appearCurve.y1,
                            CritterAnimation.appearCurve.x2, CritterAnimation.appearCurve.y2,
                            duration: CritterAnimation.transitionDuration
                          )
                        : .spring(response: CritterAnimation.transitionDuration, dampingFraction: 0.7),
                    value: state.isExpanded
                )
                .offset(x: wanderOffset)
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.001)) // keeps the hosting view hit-testable-free but visible
        .onAppear {
            scene.update(mood: state.mood)
            updateWandering(for: state.mood)
        }
        .onChange(of: state.mood) { _, newMood in
            scene.update(mood: newMood)
            updateWandering(for: newMood)
        }
        .onChange(of: state.yawnTrigger) { _, _ in
            scene.playYawn()
        }
        .onDisappear { wanderTimer?.invalidate() }
    }

    private func updateWandering(for mood: CritterMood) {
        wanderTimer?.invalidate()
        guard mood == .idle else {
            withAnimation(.easeInOut(duration: 0.4)) { wanderOffset = 0 }
            return
        }
        scheduleNextWander()
    }

    private func scheduleNextWander() {
        let delay = Double.random(in: wanderPauseRange)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.2)) {
                    wanderOffset = .random(in: wanderRange)
                }
                scheduleNextWander()
            }
        }
    }
}
