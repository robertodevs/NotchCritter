import Foundation
import Combine

enum CritterMood {
    case idle
    case alert
    case sleepy
}

/// Drives the critter's behavior. Keystroke activity and idle time feed
/// in here; CritterView just renders whatever mood/expansion state comes out.
final class CritterState: ObservableObject {
    @Published private(set) var mood: CritterMood = .idle
    @Published private(set) var isExpanded = false

    private var idleTimer: Timer?
    private let idleTimeout: TimeInterval = 45

    func registerKeystroke() {
        mood = .alert
        isExpanded = true
        resetIdleTimer()
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            self?.mood = .sleepy
            self?.isExpanded = false
        }
    }
}
