import Foundation
import Combine

enum CritterMood {
    case idle
    case alert
    case sleepy
}

/// Shared timing so the window resize (NotchWindowController) and the
/// content scale (CritterView) animate over the exact same duration,
/// starting from the same isExpanded change — keeping them in lockstep
/// instead of racing on two independent animation systems.
enum CritterAnimation {
    static let transitionDuration: TimeInterval = 0.35

    // Appear: starts slow and accelerates, like it's actually dropping out
    // of the notch under gravity rather than easing smoothly into place.
    static let appearCurve = (x1: 0.55, y1: 0.055, x2: 0.675, y2: 0.19)
}

/// Drives the critter's behavior. Keystroke activity and idle time feed
/// in here; CritterView just renders whatever mood/expansion state comes out.
final class CritterState: ObservableObject {
    @Published private(set) var mood: CritterMood = .idle
    @Published private(set) var isExpanded = false
    // Bumped (not toggled) each time a yawn should play, since CritterView
    // needs a signal it can observe even if two yawns were ever requested
    // back to back — a Bool could coalesce those into a single onChange.
    @Published private(set) var yawnTrigger = 0

    private var alertCooldownTimer: Timer?
    private var yawnTimer: Timer?
    private var sleepyTimer: Timer?
    private var hideTimer: Timer?

    // Short enough to feel instant once typing actually stops, long enough
    // that the gap between two keystrokes in a normal typing cadence never
    // triggers it (each keystroke resets this timer via registerKeystroke).
    private let alertCooldown: TimeInterval = 0.6
    // All three measured from the same last-keystroke reference point:
    // yawn (5-10s window), then mood goes sleepy (still visible, 10-15s
    // window), then it collapses back into the notch shortly after.
    private let yawnDelay: TimeInterval = 7
    private let sleepyDelay: TimeInterval = 12
    private let hideDelay: TimeInterval = 17

    func registerKeystroke() {
        mood = .alert
        isExpanded = true
        resetAlertCooldown()
        resetIdleTimers()
    }

    private func resetAlertCooldown() {
        alertCooldownTimer?.invalidate()
        alertCooldownTimer = Timer.scheduledTimer(withTimeInterval: alertCooldown, repeats: false) { [weak self] _ in
            self?.mood = .idle
        }
    }

    private func resetIdleTimers() {
        yawnTimer?.invalidate()
        sleepyTimer?.invalidate()
        hideTimer?.invalidate()

        yawnTimer = Timer.scheduledTimer(withTimeInterval: yawnDelay, repeats: false) { [weak self] _ in
            self?.yawnTrigger += 1
        }
        sleepyTimer = Timer.scheduledTimer(withTimeInterval: sleepyDelay, repeats: false) { [weak self] _ in
            self?.alertCooldownTimer?.invalidate()
            self?.mood = .sleepy
        }
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            self?.isExpanded = false
        }
    }
}
