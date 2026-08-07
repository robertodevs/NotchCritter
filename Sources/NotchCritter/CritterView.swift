import SwiftUI

/// Placeholder rendering for the critter. Swap the shape/emoji out for
/// real sprite art once the notch geometry and expand/collapse feel right.
struct CritterView: View {
    @ObservedObject var state: CritterState

    var body: some View {
        HStack {
            Spacer()
            Text(emoji)
                .font(.system(size: state.isExpanded ? 50 : 32))
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: state.isExpanded)
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.001)) // keeps the hosting view hit-testable-free but visible
    }

    private var emoji: String {
        switch state.mood {
        case .idle: return "🐾"
        case .alert: return "👀"
        case .sleepy: return "😴"
        }
    }
}
