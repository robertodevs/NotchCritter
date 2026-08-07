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

    private var alertCooldownTimer: Timer?
    private var idleTimer: Timer?
    // Short enough to feel instant once typing actually stops, long enough
    // that the gap between two keystrokes in a normal typing cadence never
    // triggers it (each keystroke resets this timer via registerKeystroke).
    private let alertCooldown: TimeInterval = 0.6
    private let idleTimeout: TimeInterval = 20

    func registerKeystroke() {
        mood = .alert
        isExpanded = true
        resetAlertCooldown()
        resetIdleTimer()
    }

    private func resetAlertCooldown() {
        alertCooldownTimer?.invalidate()
        alertCooldownTimer = Timer.scheduledTimer(withTimeInterval: alertCooldown, repeats: false) { [weak self] _ in
            self?.mood = .idle
        }
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            self?.alertCooldownTimer?.invalidate()
            self?.mood = .sleepy
            self?.isExpanded = false
        }
    }
}
