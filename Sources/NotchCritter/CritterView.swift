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
    @State private var retractTimer: Timer?

    // Driven manually (instead of a plain .animation(value:)) so hiding can
    // run its own two-phase squash-and-stretch rather than a single eased
    // scale. Starts at zero to match isExpanded's initial false.
    @State private var scale: CGSize = .zero

    // How far the critter drifts from center while idle, and the pause
    // range between drifts. Small enough to stay clear of the window edges
    // (window is 200pt wide, sprite is at most 56pt).
    private let wanderRange: ClosedRange<CGFloat> = -30...30
    private let wanderPauseRange: ClosedRange<Double> = 2.5...4.5

    private let spriteSize: CGFloat = 56
    // Fraction of the sprite's box that's transparent padding above the
    // character's actual head (measured from the source PNG: opaque
    // pixels start ~17% down from the top). The rope's bottom endpoint
    // has to land on the head itself, not the edge of the invisible box.
    private let headPaddingFraction: CGFloat = 0.17

    var body: some View {
        GeometryReader { geo in
            // The rope's anchor point (top of the notch, horizontally
            // centered) never moves — it's the sprite that wanders and
            // scales underneath it. Recomputing the line's endpoints from
            // scratch each frame (instead of moving the whole rope+sprite
            // group together) means the rope visibly tilts as the critter
            // drifts, like an actual taut tether, rather than sliding
            // sideways as one rigid unit.
            let anchor = CGPoint(x: geo.size.width / 2, y: 0)
            let visualSpriteHeight = spriteSize * scale.height
            let headTopY = geo.size.height - visualSpriteHeight * (1 - headPaddingFraction)
            let headPoint = CGPoint(x: geo.size.width / 2 + wanderOffset, y: headTopY)

            ZStack(alignment: .top) {
                RopeShape(anchor: anchor, headPoint: headPoint)
                    .stroke(RopeStyle.color, style: StrokeStyle(lineWidth: RopeStyle.width, lineCap: .round))

                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: spriteSize, height: spriteSize)
                    // Scale 0 means it's genuinely invisible at rest
                    // regardless of exactly how the window is clipping
                    // it — hiding no longer depends on pixel-perfect
                    // window geometry.
                    .scaleEffect(x: scale.width, y: scale.height, anchor: .bottom)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .offset(x: wanderOffset)
            }
        }
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
        .onChange(of: state.isExpanded) { _, expanded in
            expanded ? animateAppear() : animateRetract()
        }
        .onDisappear {
            wanderTimer?.invalidate()
            retractTimer?.invalidate()
        }
    }

    // Accelerating curve, so it feels like it's actually falling out of
    // the notch under gravity rather than easing smoothly into place.
    private func animateAppear() {
        retractTimer?.invalidate()
        withAnimation(
            .timingCurve(
                CritterAnimation.appearCurve.x1, CritterAnimation.appearCurve.y1,
                CritterAnimation.appearCurve.x2, CritterAnimation.appearCurve.y2,
                duration: CritterAnimation.transitionDuration
            )
        ) {
            scale = CGSize(width: 1, height: 1)
        }
    }

    // Two beats so it reads as the rope actually reeling the critter in,
    // not just a shrinking sprite: first a quick yank (stretches taller
    // and pinches narrower, like the rope snapping taut), then it's
    // hauled the rest of the way up and vanishes. The split durations sum
    // to CritterAnimation.transitionDuration, keeping this in lockstep
    // with the window's own collapse animation (NotchWindowController).
    // Sequenced with a cancelable Timer (matching scheduleNextWander below)
    // rather than DispatchQueue.asyncAfter, so a keystroke arriving mid-yank
    // can invalidate the pending second phase instead of racing animateAppear.
    private func animateRetract() {
        let yankDuration = CritterAnimation.transitionDuration * CritterAnimation.retractYankFraction
        let hideDuration = CritterAnimation.transitionDuration - yankDuration

        withAnimation(.easeOut(duration: yankDuration)) {
            scale = CritterAnimation.retractYankScale
        }
        retractTimer?.invalidate()
        retractTimer = Timer.scheduledTimer(withTimeInterval: yankDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: hideDuration)) {
                    scale = .zero
                }
            }
        }
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

/// A plain `Path { ... }` isn't animatable — SwiftUI has no way to
/// interpolate "two arbitrary line segments," so it would just snap to the
/// new endpoints instantly while the sprite's `.offset` eased in over the
/// same `withAnimation`, making the rope visibly arrive before the critter
/// it's tied to. Conforming to `Shape` and exposing `headPoint` through
/// `animatableData` puts the rope on the same interpolated timeline as
/// everything else driven by that transaction.
private struct RopeShape: Shape {
    var anchor: CGPoint
    var headPoint: CGPoint

    var animatableData: CGPoint.AnimatableData {
        get { headPoint.animatableData }
        set { headPoint.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: anchor)
        path.addLine(to: headPoint)
        return path
    }
}

/// Styling for the literal tether drawn in CritterView.body — the rope's
/// length itself is computed dynamically there (it has to reach from the
/// notch all the way to the sprite's head), so this just holds the fixed
/// cosmetic bits.
private enum RopeStyle {
    static let width: CGFloat = 2
    static let color = Color(red: 0.55, green: 0.4, blue: 0.24)
}
