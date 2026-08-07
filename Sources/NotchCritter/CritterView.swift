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
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: state.isExpanded ? 56 : 28, height: state.isExpanded ? 56 : 28)
                .offset(x: wanderOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: state.isExpanded)
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
