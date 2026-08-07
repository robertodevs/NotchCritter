import SwiftUI
import SpriteKit

/// Renders the critter's sprite animation, driven by CritterState's mood
/// and expansion. The SKScene owns the actual frame-by-frame animation;
/// this view just sizes it and forwards mood changes.
struct CritterView: View {
    @ObservedObject var state: CritterState

    @State private var scene = CritterSpriteScene()

    var body: some View {
        HStack {
            Spacer()
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: state.isExpanded ? 56 : 28, height: state.isExpanded ? 56 : 28)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: state.isExpanded)
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.001)) // keeps the hosting view hit-testable-free but visible
        .onAppear { scene.update(mood: state.mood) }
        .onChange(of: state.mood) { _, newMood in scene.update(mood: newMood) }
    }
}
